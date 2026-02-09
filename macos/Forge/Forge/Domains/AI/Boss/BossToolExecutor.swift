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

        let context = args["context"] as? String

        // Resolve AI service — use builderServiceResolver for roles with a preferred builder (e.g. Opus for researcher)
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
