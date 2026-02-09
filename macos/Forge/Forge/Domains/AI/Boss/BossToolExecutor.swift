import Foundation

/// Executes Boss-level tool calls: delegates to sub-agents, updates checklist, or falls through to standard tools
@MainActor
class BossToolExecutor: ToolExecuting {
    let workspace: LocalWorkspaceService
    var projectName: String
    let serviceResolver: (AIProvider) -> any AIService
    let builderServiceResolver: ((String) -> any AIService)?
    let onChecklistUpdate: ([ChecklistItem]) -> Void
    let onSubAgentEvent: (SubAgentRole, AgentEvent) -> Void
    let onProjectCreate: ((String) -> Void)?

    init(
        workspace: LocalWorkspaceService,
        projectName: String,
        serviceResolver: @escaping (AIProvider) -> any AIService,
        builderServiceResolver: ((String) -> any AIService)? = nil,
        onChecklistUpdate: @escaping ([ChecklistItem]) -> Void,
        onSubAgentEvent: @escaping (SubAgentRole, AgentEvent) -> Void,
        onProjectCreate: ((String) -> Void)? = nil
    ) {
        self.workspace = workspace
        self.projectName = projectName
        self.serviceResolver = serviceResolver
        self.builderServiceResolver = builderServiceResolver
        self.onChecklistUpdate = onChecklistUpdate
        self.onSubAgentEvent = onSubAgentEvent
        self.onProjectCreate = onProjectCreate
    }

    var priorityToolNames: Set<String> { ["create_project"] }

    /// Inner executor for standard file/search tools
    private var standardExecutor: ToolExecutor {
        ToolExecutor(workspace: workspace, projectName: projectName)
    }

    func execute(_ call: ToolCall) async throws -> String {
        switch call.name {
        case "create_project":
            return executeCreateProject(call)
        case "delegate_task":
            return try await executeDelegateTask(call)
        case "build_version":
            return try await executeBuildVersion(call)
        case "update_checklist":
            return executeUpdateChecklist(call)
        default:
            return try await standardExecutor.execute(call)
        }
    }

    // MARK: - Create Project

    private func executeCreateProject(_ call: ToolCall) -> String {
        let args = parseArguments(call.arguments)
        guard let name = args["name"] as? String, !name.isEmpty else {
            return "Error: missing project name"
        }

        // Create the workspace directory
        _ = try? workspace.createProject(name: name)

        // Update our projectName so subsequent tools use the new project
        projectName = name

        // Notify the host (ChatViewModel) to wire up AppState
        onProjectCreate?(name)

        return "Project '\(name)' created"
    }

    // MARK: - Delegate Task

    private func executeDelegateTask(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let roleString = args["role"] as? String,
              let role = SubAgentRole(rawValue: roleString),
              let instructions = args["instructions"] as? String else {
            throw ToolError.missingParameter("role and instructions")
        }

        // Researcher: use fast programmatic pipeline (web search + Groq summary)
        if role == .researcher {
            return try await executeProgrammaticResearch(instructions)
        }

        let context = args["context"] as? String

        // Resolve AI service — use builderServiceResolver for roles with a preferred builder
        let service: any AIService
        if let builder = role.preferredBuilder, let resolved = builderServiceResolver?(builder) {
            service = resolved
        } else {
            service = serviceResolver(role.preferredProvider)
        }

        // Build filtered tool set for this role (OpenAI format for Groq/GLM)
        let isAnthropic = service.provider == .claude
        let allTools: [[String: Any]] = isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat()

        let filteredTools = filterTools(allTools, allowed: role.allowedTools, isAnthropic: isAnthropic)

        // Build sub-agent prompt
        var fullInstructions = instructions
        if let context {
            fullInstructions += "\n\nCONTEXT:\n\(context)"
        }
        let systemPrompt = BossSystemPrompts.subAgent(role: role, instructions: fullInstructions)

        // Run nested agent loop
        let subExecutor = ToolExecutor(workspace: workspace, projectName: projectName)
        let agentLoop = AgentLoop()

        let result = try await agentLoop.run(
            userMessage: fullInstructions,
            history: [],
            systemPrompt: systemPrompt,
            service: service,
            executor: subExecutor,
            tools: filteredTools,
            maxIterations: role.maxIterations
        ) { [role, onSubAgentEvent] event in
            onSubAgentEvent(role, event)
        }

        return "[\(role.rawValue)] \(result.text)"
    }

    // MARK: - Programmatic Research (fast: web search + Groq summary)

    /// Fast research pipeline: 3 parallel Gemini web searches → 1 Groq summary → research.md
    private func executeProgrammaticResearch(_ instructions: String) async throws -> String {
        // 1. Read brief.md
        let brief: String
        do {
            brief = try workspace.readFile(project: projectName, path: "brief.md")
        } catch {
            return "[researcher] Error: brief.md not found. Boss must write brief.md first."
        }

        onSubAgentEvent(.researcher, .toolStart(name: "web_search", args: "Researching brand..."))

        // 2. Run 3 parallel web searches via Gemini grounding
        let queries = [
            "Tell me about this project and find the existing website: \(String(brief.prefix(500))). Find the brand's website URL, colors, typography, and visual identity.",
            "Find a competitor website for: \(String(brief.prefix(300))). Describe what makes the competitor's website effective, their design techniques and visual approach.",
            "Find modern web design inspiration outside this industry: \(String(brief.prefix(300))). Look for innovative design techniques, typography, color usage, and layout patterns."
        ]

        let executor = standardExecutor
        var searchResults: [String] = Array(repeating: "", count: 3)

        let tasks: [Task<(Int, String), Never>] = queries.enumerated().map { (i, query) in
            nonisolated(unsafe) let exec = executor
            return Task { @MainActor in
                let argsDict = ["query": query]
                guard let argsData = try? JSONSerialization.data(withJSONObject: argsDict),
                      let argsString = String(data: argsData, encoding: .utf8) else {
                    return (i, "Error: failed to encode query")
                }
                let call = ToolCall(id: "research-\(i)", name: "web_search", arguments: argsString)
                let result = (try? await exec.execute(call)) ?? "No results found."
                return (i, result)
            }
        }
        for task in tasks {
            let (i, result) = await task.value
            searchResults[i] = result
        }

        onSubAgentEvent(.researcher, .toolDone(name: "web_search", summary: "3 searches complete"))
        onSubAgentEvent(.researcher, .toolStart(name: "create_file", args: "Writing research.md..."))

        // 3. Summarize via Groq (fast, ~2-3 seconds)
        let groqService = serviceResolver(.groq)
        let summaryMessages: [[String: Any]] = [
            ["role": "system", "content": "You are a web design researcher. Write concise, factual research notes. Never guess or invent information — only use data from the provided search results. Write in the same language as the brief."],
            ["role": "user", "content": """
            Based on the project brief and search results below, write a concise research.md file.

            PROJECT BRIEF:
            \(brief)

            --- BRAND RESEARCH ---
            \(searchResults[0])

            --- COMPETITOR RESEARCH ---
            \(searchResults[1])

            --- DESIGN INSPIRATION ---
            \(searchResults[2])

            Write research.md in this exact format (max 60 lines, concise facts only):

            # Research

            ## Brand
            - Colors: [primary hex, secondary hex, background — from their actual website]
            - Typography: [font names and weights found]
            - Tone: [2-3 words describing the brand voice]
            - Key images: [describe 2-3 important images with URLs if found]

            ## Competitor: [Name] ([URL])
            - What's strong: [1-2 sentences]
            - Notable techniques: [2-3 design techniques]

            ## Inspiration: [Name] ([URL])
            - What's strong: [1-2 sentences]
            - Notable techniques: [2-3 techniques from outside the industry]

            Use ONLY information from the search results. Never invent colors, fonts, or URLs.
            """]
        ]

        let response = try await groqService.generateWithTools(
            messages: summaryMessages,
            systemPrompt: "",
            tools: []
        )

        let researchContent = response.text ?? "# Research\n\nNo research data available."

        // 4. Write research.md
        try workspace.writeFile(project: projectName, path: "research.md", content: researchContent)

        onSubAgentEvent(.researcher, .toolDone(name: "create_file", summary: "research.md written (\(researchContent.count) chars)"))

        #if DEBUG
        print("[BossToolExecutor] Programmatic research complete — \(researchContent.count) chars")
        #endif

        return "[researcher] Research complete — research.md written (\(researchContent.count) chars)"
    }

    // MARK: - Build Version

    private func executeBuildVersion(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let builderName = args["builder"] as? String,
              let version = args["version"] as? Int,
              let instructions = args["instructions"] as? String,
              let designDirection = args["design_direction"] as? String else {
            throw ToolError.missingParameter("builder, version, instructions, and design_direction")
        }

        let researchContext = args["research_context"] as? String

        // Map builder name to AI provider
        let builderProvider: AIProvider
        switch builderName {
        case "opus": builderProvider = .claude
        case "gemini": builderProvider = .gemini
        case "kimi": builderProvider = .kimi
        default: return "Error: unknown builder '\(builderName)'. Use opus, gemini, or kimi."
        }

        // Create version-specific project inside base: e.g. "coffee-shop/v1"
        let versionProjectName = "\(projectName)/v\(version)"
        _ = try? workspace.createProject(name: versionProjectName)

        // Copy research files from base project to version project
        copyResearchFiles(to: versionProjectName)

        // Verify research.md was copied — warn builder if missing
        let hasResearch = (try? workspace.readFile(project: versionProjectName, path: "research.md")) != nil
        #if DEBUG
        print("[BossToolExecutor] build_version v\(version)/\(builderName) — research.md: \(hasResearch ? "copied" : "MISSING")")
        #endif

        // Notify host about the new version project
        onProjectCreate?(versionProjectName)

        // Resolve AI service for this builder (use builderServiceResolver for model-specific services like Opus)
        let service = builderServiceResolver?(builderName) ?? serviceResolver(builderProvider)

        // Build tools for coder role + web_search (OpenAI format for Kimi/Gemini, Anthropic for Claude)
        let isAnthropic = service.provider == .claude
        let allTools: [[String: Any]] = isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat()
        var builderTools = SubAgentRole.coder.allowedTools
        builderTools.insert("web_search") // builders can search for images
        let filteredTools = filterTools(allTools, allowed: builderTools, isAnthropic: isAnthropic)

        // Build system prompt with design direction (like Apex's vector injection)
        let systemPrompt = """
        \(BossSystemPrompts.builder)

        ## ASSIGNED DESIGN DIRECTION
        Your creative direction: [\(designDirection)]
        Push the design toward [\(designDirection)]. This is your angle — own it.
        Build a complete, polished website following this direction.
        """

        var fullInstructions = instructions
        if let researchContext {
            fullInstructions += "\n\nRESEARCH CONTEXT:\n\(researchContext)"
        }
        if hasResearch {
            fullInstructions += "\n\nStart by reading brief.md and research.md, then build."
        } else {
            fullInstructions += "\n\nStart by reading brief.md, then build. Note: research.md is not available — use web_search to find brand colors and fonts yourself."
        }

        // Run nested agent loop targeting the version project
        let subExecutor = ToolExecutor(workspace: workspace, projectName: versionProjectName)
        let agentLoop = AgentLoop()

        let result = try await agentLoop.run(
            userMessage: fullInstructions,
            history: [],
            systemPrompt: systemPrompt,
            service: service,
            executor: subExecutor,
            tools: filteredTools,
            maxIterations: SubAgentRole.coder.maxIterations
        ) { [onSubAgentEvent] event in
            onSubAgentEvent(.coder, event)
        }

        // Commit the version project
        _ = try? await workspace.ensureGitRepository(project: versionProjectName)
        _ = try? await workspace.gitCommit(project: versionProjectName, message: "v\(version) built by \(builderName)")

        return "[v\(version)/\(builderName)] \(result.text)"
    }

    // MARK: - Update Checklist

    private func executeUpdateChecklist(_ call: ToolCall) -> String {
        let args = parseArguments(call.arguments)
        guard let itemsArray = args["items"] as? [[String: Any]] else {
            return "Error: missing items array"
        }

        let items: [ChecklistItem] = itemsArray.compactMap { dict in
            guard let step = dict["step"] as? String,
                  let statusString = dict["status"] as? String,
                  let status = ChecklistStatus(rawValue: statusString) else {
                return nil
            }
            return ChecklistItem(step: step, status: status)
        }

        onChecklistUpdate(items)

        // Also write checklist.md to workspace for persistence
        let markdown = items.map { item in
            let icon: String
            switch item.status {
            case .pending: icon = "⬜"
            case .inProgress: icon = "🔄"
            case .done: icon = "✅"
            case .error: icon = "❌"
            }
            return "\(icon) \(item.step)"
        }.joined(separator: "\n")

        try? workspace.writeFile(project: projectName, path: "checklist.md", content: "# Task Checklist\n\n\(markdown)\n")

        return "Checklist updated: \(items.count) items"
    }

    // MARK: - Research File Copying

    /// Copy brief.md and research.md from base project to a version project
    private func copyResearchFiles(to versionProject: String) {
        let researchFiles = ["brief.md", "research.md", "checklist.md"]
        for file in researchFiles {
            if let content = try? workspace.readFile(project: projectName, path: file) {
                try? workspace.writeFile(project: versionProject, path: file, content: content)
            }
        }
    }

    // MARK: - Helpers

    private func parseArguments(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    /// Filter tool definitions to only include allowed tools for a role
    private func filterTools(_ tools: [[String: Any]], allowed: Set<String>, isAnthropic: Bool) -> [[String: Any]] {
        tools.filter { tool in
            if isAnthropic {
                guard let name = tool["name"] as? String else { return false }
                return allowed.contains(name)
            } else {
                guard let function = tool["function"] as? [String: Any],
                      let name = function["name"] as? String else { return false }
                return allowed.contains(name)
            }
        }
    }
}
