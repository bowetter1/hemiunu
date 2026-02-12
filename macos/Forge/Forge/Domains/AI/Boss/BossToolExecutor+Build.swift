import Foundation

extension BossToolExecutor {
    // MARK: - Build Version

    func executeBuildVersion(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let builderName = args["builder"] as? String,
              let version = args["version"] as? Int,
              let instructions = args["instructions"] as? String,
              let designDirection = args["design_direction"] as? String else {
            throw ToolError.missingParameter("builder, version, instructions, and design_direction")
        }

        // Map builder name to AI provider.
        let builderProvider: AIProvider
        switch builderName {
        case "opus": builderProvider = .claude
        case "gemini": builderProvider = .gemini
        case "codex": builderProvider = .codex
        default: return "Error: unknown builder '\(builderName)'. Use opus, gemini, or codex."
        }

        // Create version-specific project inside base: e.g. "coffee-shop/v1".
        let versionProjectName = "\(projectName)/v\(version)"
        _ = try? workspace.createProject(name: versionProjectName)

        // Write agent name for sidebar display.
        let displayName = builderName.prefix(1).uppercased() + builderName.dropFirst()
        try? workspace.writeFile(project: versionProjectName, path: "agent-name.txt", content: displayName)

        // Copy research files from base project to version project.
        copyResearchFiles(to: versionProjectName)

        // Copy persistent memory to version project so builder can read/update it.
        memoryService?.copyToProject(workspace: workspace, projectName: versionProjectName)

        // Verify research.md was copied. Warn builder if missing.
        let hasResearch = (try? workspace.readFile(project: versionProjectName, path: "research.md")) != nil
        #if DEBUG
        print("[BossToolExecutor] build_version v\(version)/\(builderName) — research.md: \(hasResearch ? "copied" : "MISSING")")
        #endif

        // Notify host about the new version project.
        onProjectCreate?(versionProjectName)

        // Resolve AI service for this builder (use builderServiceResolver for model-specific services like Opus).
        let service = builderServiceResolver?(builderName) ?? serviceResolver(builderProvider)
        let modelName = service.modelName

        // Log builder start.
        buildLogger?.logBuilderStart(builder: builderName, version: version, direction: designDirection, model: modelName)

        // Build tools for coder role + web_search (OpenAI for Codex/Gemini, Anthropic for Claude).
        let isAnthropic = service.provider == .claude
        let allTools: [[String: Any]] = isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat()
        var builderTools = SubAgentRole.coder.allowedTools
        builderTools.insert("web_search")
        builderTools.insert("search_images")
        let filteredTools = filterTools(allTools, allowed: builderTools, isAnthropic: isAnthropic)

        // Build system prompt with design direction (like Apex's vector injection).
        let systemPrompt = """
        \(BossSystemPrompts.builder)

        ## ASSIGNED DESIGN DIRECTION
        Your creative direction: [\(designDirection)]
        This is YOUR vision. It defines your layout, visual hierarchy, mood, and structure.
        Research gives you brand facts — but [\(designDirection)] is how you interpret them.
        Be bold. Be different. Commit fully to this angle.
        """

        // Inject brief+research content directly to eliminate unnecessary file-reading iterations.
        let briefContent = try? workspace.readFile(project: projectName, path: "brief.md")
        let researchFileContent = try? workspace.readFile(project: versionProjectName, path: "research.md")

        var fullInstructions = instructions
        if let briefContent {
            fullInstructions += "\n\n--- PROJECT BRIEF (brief.md) ---\n\(briefContent)"
        }
        if let researchFileContent {
            fullInstructions += "\n\n--- RESEARCH (research.md) ---\n\(researchFileContent)"
        }

        // Inject persistent memory (accumulated learnings from previous projects).
        let memoryContent = try? workspace.readFile(project: versionProjectName, path: "memory.md")
        if let memoryContent, !memoryContent.isEmpty {
            fullInstructions += "\n\n--- YOUR MEMORY (learnings from previous projects) ---\n\(memoryContent)"
        }
        fullInstructions += "\n\nIMPORTANT: The brief, research, and memory content is provided above. Do NOT waste iterations calling read_file on brief.md, research.md, or memory.md — the content is already here. Start building immediately."

        // Run nested agent loop targeting the version project.
        let subExecutor = ToolExecutor(workspace: workspace, projectName: versionProjectName, onFileWrite: onFileWrite)
        let builderStartTime = CFAbsoluteTimeGetCurrent()
        let builderLabel = "v\(version)/\(displayName)"

        let makeEventHandler: (String) -> (AgentEvent) -> Void = { [onSubAgentEvent, weak buildLogger] tag in
            let label = builderLabel
            return { event in
                onSubAgentEvent(label, event)
                switch event {
                case .toolStart(let name, let args):
                    buildLogger?.logEvent("🔧", "\(tag) `\(name)` — \(String(args.prefix(80)))")
                case .toolDone(let name, let summary):
                    buildLogger?.logEvent("✓", "\(tag) `\(name)` → \(String(summary.prefix(80)))")
                case .apiResponse(let input, let output):
                    buildLogger?.logEvent("📡", "\(tag) API call", tokens: "\(input)→\(output)")
                case .error(let msg):
                    buildLogger?.logEvent("❌", "\(tag) \(msg)")
                default:
                    break
                }
            }
        }

        var result: AgentResult
        do {
            result = try await AgentLoop().run(
                userMessage: fullInstructions,
                history: [],
                systemPrompt: systemPrompt,
                service: service,
                executor: subExecutor,
                tools: filteredTools,
                maxIterations: SubAgentRole.coder.maxIterations,
                onEvent: makeEventHandler("[v\(version)/\(builderName)]")
            )

            let builderTime = CFAbsoluteTimeGetCurrent() - builderStartTime
            buildLogger?.logBuilderDone(
                builder: builderName,
                version: version,
                success: true,
                inputTokens: result.totalInputTokens,
                outputTokens: result.totalOutputTokens,
                duration: builderTime
            )

            // Persist builder memory (accumulated learnings) back to ~/Forge/memories/.
            memoryService?.saveFromProject(workspace: workspace, projectName: versionProjectName)
        } catch {
            let builderTime = CFAbsoluteTimeGetCurrent() - builderStartTime
            buildLogger?.logEvent("❌", "[v\(version)/\(builderName)] Builder error: \(error.localizedDescription)")
            buildLogger?.logBuilderDone(
                builder: builderName,
                version: version,
                success: false,
                inputTokens: 0,
                outputTokens: 0,
                duration: builderTime
            )

            // Auto-retry with gemini fallback (don't retry if already gemini).
            guard builderName != "gemini" else { throw error }
            buildLogger?.logEvent("🔄", "[v\(version)] Retrying with gemini fallback...")

            let fallbackService = builderServiceResolver?("gemini") ?? serviceResolver(.gemini)
            let fallbackTools = filterTools(ForgeTools.openAIFormat(), allowed: builderTools, isAnthropic: false)
            let retryStart = CFAbsoluteTimeGetCurrent()

            result = try await AgentLoop().run(
                userMessage: fullInstructions,
                history: [],
                systemPrompt: systemPrompt,
                service: fallbackService,
                executor: subExecutor,
                tools: fallbackTools,
                maxIterations: SubAgentRole.coder.maxIterations,
                onEvent: makeEventHandler("[v\(version)/gemini-retry]")
            )

            let retryTime = CFAbsoluteTimeGetCurrent() - retryStart
            buildLogger?.logBuilderDone(
                builder: "gemini",
                version: version,
                success: true,
                inputTokens: result.totalInputTokens,
                outputTokens: result.totalOutputTokens,
                duration: retryTime
            )
            memoryService?.saveFromProject(workspace: workspace, projectName: versionProjectName)
        }

        // Notify host that this builder finished (first one triggers preview load).
        onBuilderDone?(versionProjectName)

        // Write per-version build log.
        let buildTime = CFAbsoluteTimeGetCurrent() - builderStartTime
        let logContent = """
        # Build Log — v\(version)
        **Builder:** \(builderName)
        **Model:** \(modelName)
        **Direction:** \(designDirection)
        **Tokens:** \(result.totalInputTokens)→\(result.totalOutputTokens)
        **Time:** \(String(format: "%d:%02d", Int(buildTime) / 60, Int(buildTime) % 60))
        """
        try? workspace.writeFile(project: versionProjectName, path: "build-log.md", content: logContent)

        // Commit the version project.
        _ = try? await workspace.ensureGitRepository(project: versionProjectName)
        _ = try? await workspace.gitCommit(project: versionProjectName, message: "v\(version) built by \(builderName)")

        return "[v\(version)/\(builderName)] \(result.text)"
    }

    // MARK: - Research File Copying

    /// Copy brief.md and research.md from base project to a version project.
    func copyResearchFiles(to versionProject: String) {
        let researchFiles = ["brief.md", "research.md", "checklist.md", "project-name.txt"]
        for file in researchFiles {
            if let content = try? workspace.readFile(project: projectName, path: file) {
                try? workspace.writeFile(project: versionProject, path: file, content: content)
            }
        }
    }
}
