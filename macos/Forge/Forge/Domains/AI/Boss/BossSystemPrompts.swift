import Foundation

/// System prompts for the Boss agent and its sub-agents.
/// Prompts are loaded from ~/Forge/prompts/*.md at runtime.
/// Edit those files to customize behavior without recompiling.
enum BossSystemPrompts {

    /// Boss orchestrator prompt — loaded from boss.md
    static var boss: String { PromptLoader.boss }

    /// Builder prompt — loaded from builder.md
    static var builder: String { PromptLoader.builder }

    /// Researcher prompt — loaded from researcher.md
    static var researcher: String { PromptLoader.researcher }

    /// Sub-agent system prompt — role-specific instructions
    static func subAgent(role: SubAgentRole, instructions: String) -> String {
        let roleDescription: String
        switch role {
        case .coder:
            roleDescription = builder
        case .researcher:
            roleDescription = researcher
        case .reviewer:
            roleDescription = """
            You are a Forge Reviewer agent — a code quality specialist.
            You review web code for quality, accessibility, and best practices.

            RULES:
            - Read files carefully before providing feedback
            - Check for accessibility (alt text, ARIA labels, contrast)
            - Check for responsive design and mobile support
            - Provide specific, actionable feedback
            """
        case .tester:
            roleDescription = """
            You are a Forge Tester agent — a visual QA specialist.
            You take screenshots of the built website and analyze them for visual quality.

            RULES:
            - Use take_screenshot to capture the current state of the site
            - Use review_screenshot to analyze layout, colors, typography, responsiveness
            - Report specific issues with clear descriptions
            - Suggest concrete fixes for any problems found
            """
        }

        return """
        \(roleDescription)

        YOUR TASK:
        \(instructions)

        Complete the task using your available tools. After finishing, respond with a brief summary of what you did.
        """
    }
}
