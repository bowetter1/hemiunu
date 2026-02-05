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

    /// Set during restore to prevent loadLocalVersions from overwriting lastKnownVersion
    private var restoredVersion: Int? = nil
    /// Prevent concurrent/redundant version loads
    private var isLoadingVersions = false

    private let appState: AppState
    private var client: APIClient { appState.client }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Version Management

    func loadVersions(projectId: String, pageId: String) {
        // Local projects: load from git history
        if projectId.hasPrefix("local:") {
            loadLocalVersions(projectId: projectId)
            return
        }

        Task {
            do {
                let versions = try await client.pageService.getVersions(projectId: projectId, pageId: pageId)
                pageVersions = versions
                if let page = appState.pages.first(where: { $0.id == pageId }) {
                    lastKnownVersion = page.currentVersion
                }
            } catch {
                pageVersions = []
            }
        }
    }

    func restoreVersion(project: Project, pageId: String, version: Int) {
        // Local projects: restore from git
        if project.id.hasPrefix("local:") {
            restoreLocalVersion(projectId: project.id, version: version)
            return
        }

        Task {
            do {
                let updated = try await client.pageService.restoreVersion(
                    projectId: project.id,
                    pageId: pageId,
                    version: version
                )
                if let index = appState.pages.firstIndex(where: { $0.id == pageId }) {
                    appState.pages[index] = updated
                }
            } catch {
                // Version restore failed
            }
        }
    }

    /// Called when selected page changes
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

    /// Called when pages array updates — detect version changes
    func handlePagesUpdate(projectId: String, selectedPageId: String?, newPages: [Page]) {
        // For local projects, always reload versions (new commit may exist)
        if projectId.hasPrefix("local:") {
            loadLocalVersions(projectId: projectId)
            return
        }

        guard let pageId = selectedPageId,
              let page = newPages.first(where: { $0.id == pageId }) else { return }

        if page.currentVersion != lastKnownVersion {
            lastKnownVersion = page.currentVersion
            loadVersions(projectId: projectId, pageId: pageId)
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

                // Reload pages from disk
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
