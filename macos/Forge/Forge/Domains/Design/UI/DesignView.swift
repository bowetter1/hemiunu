import SwiftUI
import AppKit

/// Main design mode container
struct DesignView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var viewModel: DesignViewModel
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedPageId: String?
    var onProjectCreated: ((String) -> Void)? = nil

    var selectedPage: Page? {
        guard let pageId = selectedPageId else { return nil }
        return appState.pages.first { $0.id == pageId }
    }

    var body: some View {
        if let project = appState.currentProject {
            projectContent(project)
                .onChange(of: selectedPageId) { _, newPageId in
                    viewModel.handlePageChange(projectId: project.id, pageId: newPageId)
                }
                .onChange(of: appState.pages) { _, newPages in
                    viewModel.handlePagesUpdate(projectId: project.id, selectedPageId: selectedPageId, newPages: newPages)
                }
                .onAppear {
                    if let pageId = selectedPageId {
                        viewModel.handlePageChange(projectId: project.id, pageId: pageId)
                    }
                }
        } else {
            welcomeView
        }
    }

    // MARK: - Welcome View (no project)

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Welcome to Forge")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Build anything. Just describe it.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Project Content

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
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
        } else {
            if let firstPage = appState.pages.first {
                WebPreview(
                    html: firstPage.html,
                    projectId: project.id,
                    sidebarVisible: sidebarVisible,
                    toolsPanelVisible: toolsPanelVisible,
                    selectedDevice: appState.selectedDevice
                )
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
                Text("The local project at \(baseURL.path) has no index.html")
                    .font(.caption)
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
