import SwiftUI

extension ChatViewModel {
    // MARK: - Actions

    /// Main send action — routes to boss coordinator
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Local project without active boss: auto-resume
        if !boss.isActive, let project = appState.currentProject, project.id.hasPrefix("local:") {
            boss.resumeForLocalProject(project.id)
        }

        boss.send(text, setLoading: { [weak self] loading in self?.isLoading = loading })
    }

    /// Reset chat state for a new project
    func resetForProject() {
        isLoading = false
    }
}
