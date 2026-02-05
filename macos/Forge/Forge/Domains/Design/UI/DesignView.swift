import SwiftUI
import AppKit

/// Main design mode container
struct DesignView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var viewModel: DesignViewModel
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedPageId: String?
    var showResearchJSON: Bool = false
    var onProjectCreated: ((String) -> Void)? = nil

    var selectedPage: Page? {
        guard let pageId = selectedPageId else { return nil }
        return appState.pages.first { $0.id == pageId }
    }

    var body: some View {
        if appState.currentProject != nil {
            projectContent
                .onChange(of: selectedPageId) { _, newPageId in
                    if let project = appState.currentProject {
                        viewModel.handlePageChange(projectId: project.id, pageId: newPageId)
                    }
                }
                .onChange(of: appState.pages) { _, newPages in
                    if let project = appState.currentProject {
                        viewModel.handlePagesUpdate(projectId: project.id, selectedPageId: selectedPageId, newPages: newPages)
                    }
                }
                .onAppear {
                    if let project = appState.currentProject, let pageId = selectedPageId {
                        viewModel.handlePageChange(projectId: project.id, pageId: pageId)
                    }
                }
        } else {
            BriefBuilderView(appState: appState) { projectId in
                onProjectCreated?(projectId)
            }
        }
    }

    @ViewBuilder
    private var projectContent: some View {
        if let project = appState.currentProject {
            if appState.isLocalProject, let localURL = appState.localPreviewURL {
                localPreviewContent(project: project, baseURL: localURL)
            } else if let page = selectedPage {
                WebPreview(
                    html: page.html,
                    projectId: project.id,
                    sidebarVisible: sidebarVisible,
                    toolsPanelVisible: toolsPanelVisible,
                    selectedDevice: appState.selectedDevice
                )
            } else if let mainPage = appState.pages.first(where: { $0.layoutVariant == nil }) {
                WebPreview(html: mainPage.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
            } else if let firstPage = appState.pages.first {
                WebPreview(html: firstPage.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
            } else {
                GeneratingView(message: "Loading...")
            }
        }
    }

    @ViewBuilder
    private func localPreviewContent(project: Project, baseURL: URL) -> some View {
        let projectName = appState.localProjectName(from: project.id) ?? ""
        let prefix = "local-page-\(projectName)/"

        let relativePath: String? = {
            if let pageId = selectedPageId, pageId.hasPrefix(prefix) {
                return String(pageId.dropFirst(prefix.count))
            }
            return appState.workspace.findMainHTML(project: projectName)
        }()

        if let relativePath {
            let fileURL = baseURL.appendingPathComponent(relativePath)
            WebPreview(
                html: "",
                localFileURL: fileURL,
                refreshToken: appState.previewRefreshToken,
                sidebarVisible: sidebarVisible,
                toolsPanelVisible: toolsPanelVisible,
                selectedDevice: appState.selectedDevice
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No HTML file found")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Button("Open in Finder") {
                    NSWorkspace.shared.open(baseURL)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Design State Views

struct GeneratingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
