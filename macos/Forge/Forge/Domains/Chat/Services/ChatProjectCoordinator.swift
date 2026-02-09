import Foundation

@MainActor
protocol ChatProjectUpdating {
    func commitAndRefresh(projectName: String, commitMessage: String) async
}

@MainActor
final class AppStateChatProjectCoordinator: ChatProjectUpdating {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func commitAndRefresh(projectName: String, commitMessage: String) async {
        guard let appState else { return }

        _ = try? await appState.workspace.gitCommit(project: projectName, message: commitMessage)
        await appState.syncLocalVersionState(projectName: projectName)
        appState.setPages(appState.workspace.loadPages(project: projectName))
        appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
        appState.refreshLocalProjects()
        appState.refreshPreview()
    }
}
