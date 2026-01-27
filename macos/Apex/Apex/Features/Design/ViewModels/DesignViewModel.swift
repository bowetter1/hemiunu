import SwiftUI
import Combine

/// DesignViewModel — owns version tracking state for the design view
@MainActor
class DesignViewModel: ObservableObject {
    @Published var pageVersions: [PageVersion] = []
    @Published var lastKnownVersion: Int = 0

    private let appState: AppState
    private var client: APIClient { appState.client }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Version Management

    func loadVersions(projectId: String, pageId: String) {
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
        guard let pageId = selectedPageId,
              let page = newPages.first(where: { $0.id == pageId }) else { return }

        if page.currentVersion != lastKnownVersion {
            lastKnownVersion = page.currentVersion
            loadVersions(projectId: projectId, pageId: pageId)
        }
    }
}
