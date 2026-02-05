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

    private var client: APIClient { appState.client }

    // Find the selected page from sidebar
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
            BriefBuilderView(appState: appState) { projectId in
                onProjectCreated?(projectId)
            }
        }
    }

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        // Show research data if selected
        if showResearchJSON {
            if let md = project.researchMd, !md.isEmpty {
                ResearchMarkdownView(markdown: md)
            } else if let moodboard = project.moodboard {
                ResearchJSONView(moodboard: moodboard)
            }
        }
        // Local project: load HTML from file URL
        else if appState.isLocalProject, let localURL = appState.localPreviewURL {
            localPreviewContent(project: project, baseURL: localURL)
        }
        // If a specific page is selected from sidebar, show it
        else if let page = selectedPage {
            WebPreview(
                html: page.html,
                projectId: project.id,
                sidebarVisible: sidebarVisible,
                toolsPanelVisible: toolsPanelVisible,
                selectedDevice: appState.selectedDevice
            )
        } else {
            // Otherwise show based on project status
            switch project.status {
            case .brief:
                GeneratingView(message: "Searching for brand info...")

            case .clarification:
                GeneratingView(message: "Waiting for your input...")

            case .researching:
                GeneratingView(message: "Researching brand...")

            case .researchDone:
                // Research complete — show markdown + generate button
                ResearchDoneView(
                    project: project,
                    appState: appState
                )

            case .moodboard:
                // Legacy — show markdown if available
                if let md = project.researchMd, !md.isEmpty {
                    ResearchMarkdownView(markdown: md)
                } else {
                    GeneratingView(message: "Researching brand...")
                }

            case .layouts:
                // Show first layout by default, user can select others from sidebar
                if let firstLayout = appState.pages.first(where: { $0.layoutVariant != nil }) {
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
                } else {
                    GeneratingView(message: "Loading layouts...")
                }

            case .building:
                GeneratingView(message: "Building project...")

            case .running:
                if let previewUrl = project.sandboxPreviewUrl {
                    WebPreview(html: "", projectId: project.id, sandboxPreviewUrl: previewUrl, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
                } else {
                    GeneratingView(message: "Running...")
                }

            case .editing, .done:
                if let mainPage = appState.pages.first(where: { $0.layoutVariant == nil }) {
                    WebPreview(html: mainPage.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
                } else if let firstLayout = appState.pages.first(where: { $0.layoutVariant != nil }) {
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible, selectedDevice: appState.selectedDevice)
                } else {
                    GeneratingView(message: "Loading...")
                }

            case .failed:
                ErrorView(message: project.errorMessage ?? "An error occurred")
            }
        }
    }

    @ViewBuilder
    private func localPreviewContent(project: Project, baseURL: URL) -> some View {
        let projectName = appState.localProjectName(from: project.id) ?? ""
        let prefix = "local-page-\(projectName)/"

        // Use selected page's file path if available, otherwise fall back to main HTML
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

/// Welcome view shown when no project is selected
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Welcome to Apex")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Describe your website to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading view with a message shown during generation
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

/// Error view showing an error message
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

// MARK: - Research JSON View

struct ResearchMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text("Brand Research")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: copyMarkdown) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Markdown content
            ScrollView {
                if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Fallback: show raw markdown
                    Text(markdown)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
}

// MARK: - Research Done View (with Generate button)

struct ResearchDoneView: View {
    let project: Project
    @ObservedObject var appState: AppState
    @State private var isGenerating = false

    private var client: APIClient { appState.client }

    var body: some View {
        VStack(spacing: 0) {
            // Research markdown content
            if let md = project.researchMd, !md.isEmpty {
                ResearchMarkdownView(markdown: md)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    Text("Research complete")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Generate Layout button bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research complete")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Review the research above, then generate your layout")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: generateLayout) {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        Text(isGenerating ? "Generating..." : "Generate Layout")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isGenerating ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func generateLayout() {
        isGenerating = true
        Task {
            do {
                let _ = try await client.projectService.generate(projectId: project.id)
                // WebSocket will notify when layouts are ready
            } catch {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

struct ResearchJSONView: View {
    let moodboard: MoodboardContainer

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text("Research Data (JSON)")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: copyJSON) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // JSON content
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(moodboard),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    private func copyJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(jsonString, forType: .string)
    }
}
