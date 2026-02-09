import SwiftUI

/// DesignViewModel — owns version tracking state for the design view
@MainActor
@Observable
class DesignViewModel {
    var pageVersions: [PageVersion] = [] {
        didSet { appState.pageVersions = pageVersions }
    }
    var lastKnownVersion: Int = 1 {
        didSet { appState.currentVersionNumber = lastKnownVersion }
    }

    private var restoredVersion: Int? = nil
    private var isLoadingVersions = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func loadVersions(projectId: String, pageId: String) {
        if projectId.hasPrefix("local:") {
#if DEBUG
            print("[Versions][DesignVM] loadVersions local projectId=\(projectId) pageId=\(pageId)")
#endif
            loadLocalVersions(projectId: projectId)
            return
        }
#if DEBUG
        print("[Versions][DesignVM] loadVersions ignored non-local projectId=\(projectId)")
#endif
    }

    func restoreVersion(project: Project, pageId: String, version: Int) {
        if project.id.hasPrefix("local:") {
#if DEBUG
            print("[Versions][DesignVM] restoreVersion local projectId=\(project.id) pageId=\(pageId) target=v\(version)")
#endif
            restoreLocalVersion(projectId: project.id, version: version)
        } else {
#if DEBUG
            print("[Versions][DesignVM] restoreVersion ignored non-local projectId=\(project.id)")
#endif
        }
    }

    func handlePageChange(projectId: String, pageId: String?) {
        if let pageId = pageId {
            if let page = appState.pages.first(where: { $0.id == pageId }) {
                lastKnownVersion = page.currentVersion
            }
#if DEBUG
            print("[Versions][DesignVM] handlePageChange projectId=\(projectId) pageId=\(pageId) lastKnown=\(lastKnownVersion)")
#endif
            loadVersions(projectId: projectId, pageId: pageId)
        } else {
#if DEBUG
            print("[Versions][DesignVM] handlePageChange cleared (nil pageId)")
#endif
            pageVersions = []
        }
    }

    func handlePagesUpdate(projectId: String, selectedPageId: String?, newPages: [Page]) {
        if projectId.hasPrefix("local:") {
#if DEBUG
            print("[Versions][DesignVM] handlePagesUpdate local projectId=\(projectId) pages=\(newPages.count)")
#endif
            loadLocalVersions(projectId: projectId)
        } else {
#if DEBUG
            print("[Versions][DesignVM] handlePagesUpdate ignored non-local projectId=\(projectId)")
#endif
        }
    }

    private func loadLocalVersions(projectId: String) {
        guard !isLoadingVersions else { return }
        guard let projectName = appState.localProjectName(from: projectId) else {
#if DEBUG
            print("[Versions][DesignVM] loadLocalVersions invalid projectId=\(projectId)")
#endif
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
#if DEBUG
                print("[Versions][DesignVM] loadLocalVersions project=\(projectName) count=\(versions.count) current=\(lastKnownVersion)")
#endif
            } catch {
#if DEBUG
                print("[Versions][DesignVM] loadLocalVersions FAILED project=\(projectName) error=\(error.localizedDescription)")
#endif
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
#if DEBUG
                print("[Versions][DesignVM] restoreLocalVersion DONE project=\(projectName) target=v\(version)")
#endif
            } catch {
#if DEBUG
                print("[Versions][DesignVM] restoreLocalVersion FAILED project=\(projectName) target=v\(version) error=\(error.localizedDescription)")
#endif
                // Restore failed
            }
        }
    }
}
