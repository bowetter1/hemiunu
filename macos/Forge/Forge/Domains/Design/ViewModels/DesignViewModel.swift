import SwiftUI
import Combine

/// DesignViewModel — owns version tracking state for the design view
@MainActor
class DesignViewModel: ObservableObject {
    @Published var pageVersions: [PageVersion] = [] {
        didSet { appState.pageVersions = pageVersions }
    }
    @Published var lastKnownVersion: Int = 1 {
        didSet { appState.currentVersionNumber = lastKnownVersion }
    }

    private var restoredVersion: Int? = nil
    private var isLoadingVersions = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Version Management

    func loadVersions(projectId: String, pageId: String) {
        if projectId.hasPrefix("local:") {
            loadLocalVersions(projectId: projectId)
            return
        }
        // No server version loading in Forge
        pageVersions = []
    }

    func restoreVersion(project: Project, pageId: String, version: Int) {
        if project.id.hasPrefix("local:") {
            restoreLocalVersion(projectId: project.id, version: version)
            return
        }
    }

    func handlePageChange(projectId: String, pageId: String?) {
        if let pageId = pageId {
            if let page = appState.pages.first(where: { $0.id == pageId }) {
                lastKnownVersion = page.currentVersion
            }
            loadVersions(projectId: projectId, pageId: pageId)
        } else {
            pageVersions = []
        }
    }

    func handlePagesUpdate(projectId: String, selectedPageId: String?, newPages: [Page]) {
        if projectId.hasPrefix("local:") {
            loadLocalVersions(projectId: projectId)
            return
        }
    }

    // MARK: - Local Versioning (Git)

    private func loadLocalVersions(projectId: String) {
        guard !isLoadingVersions else { return }
        guard let projectName = appState.localProjectName(from: projectId) else {
            pageVersions = []
            return
        }

        isLoadingVersions = true
        Task {
            defer { isLoadingVersions = false }
            do {
                let versions = try await LocalWorkspaceService.shared.gitVersions(project: projectName)
                pageVersions = versions
                if let restored = restoredVersion {
                    lastKnownVersion = restored
                    restoredVersion = nil
                } else if let latest = versions.last {
                    lastKnownVersion = latest.version
                }
            } catch {
                pageVersions = []
            }
        }
    }

    private func restoreLocalVersion(projectId: String, version: Int) {
        guard let projectName = appState.localProjectName(from: projectId),
              let target = pageVersions.first(where: { $0.version == version }) else { return }

        Task {
            do {
                try await LocalWorkspaceService.shared.gitRestore(project: projectName, commitHash: target.id)
                let newPages = LocalWorkspaceService.shared.loadPages(project: projectName)
                restoredVersion = version
                appState.pages = newPages
                appState.previewRefreshToken = UUID()
            } catch {
                // Restore failed
            }
        }
    }
}
