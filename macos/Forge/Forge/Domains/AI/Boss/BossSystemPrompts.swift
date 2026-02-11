import Foundation

/// System prompts for the Boss agent and its sub-agents.
/// Prompts are loaded from ~/Forge/prompts/*.md at runtime.
/// Edit those files to customize behavior without recompiling.
enum BossSystemPrompts {

    /// Boss orchestrator prompt — loaded from boss.md
    static var boss: String { PromptLoader.boss }

    /// Builder prompt — loaded from builder.md
    static var builder: String { PromptLoader.builder }

    /// Reviewer prompt — loaded from reviewer.md
    static var reviewer: String { PromptLoader.reviewer }

    /// Tester prompt — loaded from tester.md
    static var tester: String { PromptLoader.tester }

    /// Sub-agent system prompt — role-specific instructions
    static func subAgent(role: SubAgentRole, instructions: String) -> String {
        let roleDescription: String
        switch role {
        case .coder:
            roleDescription = builder
        case .reviewer:
            roleDescription = reviewer
        case .tester:
            roleDescription = tester
        }

        return """
        \(roleDescription)

        YOUR TASK:
        \(instructions)

        Complete the task using your available tools. After finishing, respond with a brief summary of what you did.
        """
    }
}
