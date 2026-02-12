import Foundation

extension BossToolExecutor {
    // MARK: - Delegate Task

    func executeDelegateTask(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let roleString = args["role"] as? String,
              let role = SubAgentRole(rawValue: roleString),
              let instructions = args["instructions"] as? String else {
            throw ToolError.missingParameter("role and instructions")
        }

        let context = args["context"] as? String

        // Resolve AI service. Use builderServiceResolver for roles with a preferred builder.
        let service: any AIService
        if let builder = role.preferredBuilder, let resolved = builderServiceResolver?(builder) {
            service = resolved
        } else {
            service = serviceResolver(role.preferredProvider)
        }

        // Build filtered tool set for this role (OpenAI format for Groq/GLM).
        let isAnthropic = service.provider == .claude
        let allTools: [[String: Any]] = isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat()
        let filteredTools = filterTools(allTools, allowed: role.allowedTools, isAnthropic: isAnthropic)

        // Build sub-agent prompt.
        var fullInstructions = instructions
        if let context {
            fullInstructions += "\n\nCONTEXT:\n\(context)"
        }
        let systemPrompt = BossSystemPrompts.subAgent(role: role, instructions: fullInstructions)

        // Run nested agent loop.
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
        ) { [onSubAgentEvent] event in
            onSubAgentEvent(role.rawValue, event)
        }

        return "[\(role.rawValue)] \(result.text)"
    }
}
