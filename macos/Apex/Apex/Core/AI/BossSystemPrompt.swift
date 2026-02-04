import Foundation

enum BossSystemPrompt {

    /// Build the boss prompt dynamically from MD files in the workspace.
    /// Injects vector direction when provided.
    static func bootstrap(workspaceURL: URL?, vector: String? = nil) -> String {
        guard let url = workspaceURL else { return fallback }

        // Read the skill file
        let skillPath = url.appendingPathComponent("skills/solo.md").path
        guard let skill = try? String(contentsOfFile: skillPath, encoding: .utf8),
              !skill.isEmpty else {
            return fallback
        }

        // Read checklist.md
        let checklistPath = url.appendingPathComponent("checklist.md").path
        let checklist = (try? String(contentsOfFile: checklistPath, encoding: .utf8)) ?? ""

        var prompt = skill

        if !checklist.isEmpty {
            prompt += "\n\n## Current Checklist\n\(checklist)"
        }

        // Inject vector direction
        if let vector, !vector.isEmpty {
            prompt += """

            \n\n## ASSIGNED VECTOR
            Your creative direction: [\(vector)]
            Push the brand toward [\(vector)]. This is your angle — own it.
            """
        }

        return prompt
    }

    /// Minimal fallback if workspace MD files are missing
    private static var fallback: String {
        """
        You are Boss in Apex. Read skills/solo.md and checklist.md \
        in your current working directory and follow the checklist step by step.
        """
    }
}
