import SwiftUI
import AppKit

/// Main design mode container
struct DesignView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var wsClient: WebSocketManager
    @StateObject private var viewModel: DesignViewModel
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedPageId: String?
    var showResearchJSON: Bool = false
    var onProjectCreated: ((String) -> Void)? = nil

    private var client: APIClient { appState.client }

    init(appState: AppState, wsClient: WebSocketManager, sidebarVisible: Bool = true, toolsPanelVisible: Bool = true, selectedPageId: String? = nil, showResearchJSON: Bool = false, onProjectCreated: ((String) -> Void)? = nil) {
        self.appState = appState
        self.wsClient = wsClient
        _viewModel = StateObject(wrappedValue: DesignViewModel(appState: appState))
        self.sidebarVisible = sidebarVisible
        self.toolsPanelVisible = toolsPanelVisible
        self.selectedPageId = selectedPageId
        self.showResearchJSON = showResearchJSON
        self.onProjectCreated = onProjectCreated
    }

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
        // If a specific page is selected from sidebar, show it
        else if let page = selectedPage {
            WebPreview(
                html: page.html,
                projectId: project.id,
                sidebarVisible: sidebarVisible,
                toolsPanelVisible: toolsPanelVisible,
                versions: viewModel.pageVersions,
                currentVersion: page.currentVersion,
                onRestoreVersion: { version in
                    viewModel.restoreVersion(project: project, pageId: page.id, version: version)
                }
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
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else {
                    GeneratingView(message: "Loading layouts...")
                }

            case .editing, .done:
                if let mainPage = appState.pages.first(where: { $0.layoutVariant == nil }) {
                    WebPreview(html: mainPage.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else if let firstLayout = appState.pages.first(where: { $0.layoutVariant != nil }) {
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else {
                    GeneratingView(message: "Loading...")
                }

            case .failed:
                ErrorView(message: project.errorMessage ?? "An error occurred")
            }
        }
    }

}

// MARK: - Design Command Bar

struct DesignCommandBar: View {
    @ObservedObject var appState: AppState
    @State private var commandText = ""
    @State private var showStartSheet = false
    @State private var pendingBrief = ""

    private var client: APIClient { appState.client }

    var body: some View {
        CommandBar(
            text: $commandText,
            placeholder: placeholderText
        ) {
            processCommand()
        }
        .sheet(isPresented: $showStartSheet) {
            StartProjectSheet(
                isPresented: $showStartSheet,
                client: client,
                initialBrief: pendingBrief
            ) { projectId in
                // Project created from sheet
            }
        }
    }

    private var placeholderText: String {
        if let project = appState.currentProject {
            switch project.status {
            case .editing, .done:
                return "Describe what you want to change..."
            default:
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    private func processCommand() {
        guard !commandText.isEmpty else { return }
        let text = commandText
        commandText = ""

        if let project = appState.currentProject,
           project.status == .editing || project.status == .done {
            editCurrentPage(instruction: text)
        } else {
            // No project — open the start project sheet with typed text as brief
            pendingBrief = text
            showStartSheet = true
        }
    }

    private func editCurrentPage(instruction: String) {
        guard let project = appState.currentProject,
              let page = appState.pages.first(where: { $0.layoutVariant == nil }) else { return }

        Task {
            do {
                let updated = try await client.pageService.edit(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction
                )
                await MainActor.run {
                    if let index = appState.pages.firstIndex(where: { $0.id == page.id }) {
                        appState.pages[index] = updated
                    }
                }
            } catch {
                // Page edit failed
            }
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
                    .background(isGenerating ? Color.gray : Color.orange)
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
