import Foundation

extension BossToolExecutor {
    // MARK: - Create Project

    func executeCreateProject(_ call: ToolCall) -> String {
        let args = parseArguments(call.arguments)
        guard let name = args["name"] as? String, !name.isEmpty else {
            return "Error: missing project name"
        }

        // Create the workspace directory.
        _ = try? workspace.createProject(name: name)

        // Update our projectName so subsequent tools use the new project.
        projectName = name

        // Update logger to write to the new project.
        buildLogger?.updateProjectName(name)
        buildLogger?.logPhase("Phase 1 — Setup")
        buildLogger?.logEvent("🏗️", "Project created: \(name)")

        // Notify the host (ChatViewModel) to wire up AppState.
        onProjectCreate?(name)

        return "Project '\(name)' created"
    }
}
