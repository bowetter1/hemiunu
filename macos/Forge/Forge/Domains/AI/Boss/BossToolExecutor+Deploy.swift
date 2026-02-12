import Foundation

extension BossToolExecutor {
    // MARK: - Deploy to Sandbox

    func executeDeployToSandbox(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let version = args["version"] as? String else {
            throw ToolError.missingParameter("version")
        }

        // Resolve the project to deploy (e.g. "my-site/v1")
        let deployProject: String
        if projectName.contains("/") {
            // Already a versioned project — replace version
            let parent = projectName.components(separatedBy: "/").first ?? projectName
            deployProject = "\(parent)/\(version)"
        } else {
            deployProject = "\(projectName)/\(version)"
        }

        // Verify project exists
        guard workspace.projectExists(deployProject) else {
            return "Error: project '\(deployProject)' not found. Available projects may use a different version."
        }

        // Resolve deployer service (Opus for reliability)
        let service = builderServiceResolver?("opus") ?? serviceResolver(.claude)

        // Build tool set filtered for .deployer role
        let isAnthropic = service.provider == .claude
        let allTools: [[String: Any]] = isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat()
        let filteredTools = filterTools(allTools, allowed: SubAgentRole.deployer.allowedTools, isAnthropic: isAnthropic)

        // Build system prompt from deployer.md
        let systemPrompt = BossSystemPrompts.deployer

        // Inject project file listing into instructions
        let files = workspace.listFiles(project: deployProject)
        let fileListing = files
            .filter { !$0.isDirectory }
            .map { "  \($0.path) (\($0.size)B)" }
            .joined(separator: "\n")

        let instructions = """
        Deploy the project "\(deployProject)" to a Daytona sandbox.

        PROJECT FILES:
        \(fileListing)

        The project is at workspace path "\(deployProject)". Use list_files and read_file to inspect files if needed.
        Upload all project files to /home/daytona/site/ in the sandbox, then install dependencies and start a server.
        Return the public preview URL when done.
        """

        // Run deployer agent loop
        let subExecutor = ToolExecutor(workspace: workspace, projectName: deployProject, onFileWrite: onFileWrite)
        let deployerLabel = "deploy/\(version)"

        let eventHandler: (AgentEvent) -> Void = { [onSubAgentEvent] event in
            onSubAgentEvent(deployerLabel, event)
        }

        let result = try await AgentLoop().run(
            userMessage: instructions,
            history: [],
            systemPrompt: systemPrompt,
            service: service,
            executor: subExecutor,
            tools: filteredTools,
            maxIterations: SubAgentRole.deployer.maxIterations,
            onEvent: eventHandler
        )

        // Parse result for deploy URL
        if let range = result.text.range(of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.works"#, options: .regularExpression) {
            let url = String(result.text[range])
            return "Deployed! Public URL: \(url)"
        }

        return result.text
    }
}
