import SwiftUI

/// Main app router - handles navigation between modes
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var client: APIClient

    init() {
        _client = ObservedObject(wrappedValue: AppState.shared.client)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Unified Sidebar (Files/Chat toggle)
            if appState.showSidebar {
                UnifiedSidebar(
                    client: client,
                    webSocket: appState.wsClient,
                    currentMode: appState.currentMode,
                    selectedProjectId: $appState.selectedProjectId,
                    selectedVariantId: $appState.selectedVariantId,
                    selectedPageId: $appState.selectedPageId,
                    onNewProject: {
                        appState.clearCurrentProject()
                    },
                    onProjectCreated: { projectId in
                        appState.selectedProjectId = projectId
                    }
                )
            }

            // Main area with content + tools panel
            ZStack(alignment: .top) {
                // Background
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                GridBackground()

                // Content layer
                HStack(spacing: 0) {
                    // Main content card
                    VStack(spacing: 0) {
                        // Spacer for topbar
                        Spacer()
                            .frame(height: 70)

                        // Content with rounded corners
                        modeContent
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .padding(.bottom, 16)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)

                    // Right tools panel placeholder
                    ToolsPanel(client: client)
                        .padding(.top, 70)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }

                // Topbar layer (above content)
                VStack {
                    Topbar(
                        showSidebar: $appState.showSidebar,
                        selectedMode: $appState.currentMode,
                        appearanceMode: $appState.appearanceMode,
                        isConnected: appState.isConnected,
                        errorMessage: appState.errorMessage,
                        hasProject: client.currentProject != nil,
                        logs: client.projectLogs
                    )
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .zIndex(10)
            }
        }
        .onAppear {
            Task {
                await appState.connect()
            }
        }
        .onChange(of: appState.selectedProjectId) { _, newId in
            if let id = newId {
                Task {
                    await appState.loadProject(id: id)
                }
            }
        }
        .onChange(of: appState.wsClient.lastEvent) { _, newEvent in
            handleWebSocketEvent(newEvent)
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appState.currentMode {
        case .design:
            DesignView(
                client: client,
                wsClient: appState.wsClient,
                sidebarVisible: appState.showSidebar,
                selectedPageId: appState.selectedPageId
            )
        case .code:
            CodeView(client: client, selectedPageId: $appState.selectedPageId)
        }
    }

    // MARK: - WebSocket

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event,
              let projectId = client.currentProject?.id else { return }

        Task {
            switch event {
            case .moodboardReady, .layoutsReady, .statusChanged, .pageUpdated:
                await appState.loadProject(id: projectId)
            case .clarificationNeeded:
                // Also reload project to update status
                await appState.loadProject(id: projectId)
            case .error(let message):
                appState.errorMessage = message
            default:
                break
            }
        }
    }
}

// MARK: - Tools Panel

/// Right-side tools panel for actions and settings
struct ToolsPanel: View {
    @ObservedObject var client: APIClient
    @State private var isExpanded = true

    private let panelWidth: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedPanel
            } else {
                collapsedPanel
            }
        }
        .frame(width: isExpanded ? panelWidth : 44)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var expandedPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Tools")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false } }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Tools content
            ScrollView {
                VStack(spacing: 12) {
                    // Generate Site
                    ToolCard(
                        icon: "globe",
                        title: "Generate Site",
                        description: "Create full website from layout",
                        color: .blue
                    ) {
                        // TODO: Implement generate site
                    }

                    // Export
                    ToolCard(
                        icon: "square.and.arrow.up",
                        title: "Export",
                        description: "Download HTML/CSS files",
                        color: .green
                    ) {
                        // TODO: Implement export
                    }

                    // Design Tokens
                    ToolCard(
                        icon: "paintpalette",
                        title: "Design Tokens",
                        description: "Colors, fonts, spacing",
                        color: .purple
                    ) {
                        // TODO: Show design tokens
                    }

                    // Version History
                    if client.currentProject != nil {
                        ToolCard(
                            icon: "clock.arrow.circlepath",
                            title: "History",
                            description: "Page version history",
                            color: .orange
                        ) {
                            // TODO: Show version history
                        }
                    }
                }
                .padding(12)
            }

            Spacer()
        }
    }

    private var collapsedPanel: some View {
        VStack(spacing: 16) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Divider()
                .frame(width: 20)

            // Collapsed tool icons
            VStack(spacing: 12) {
                CollapsedToolButton(icon: "globe", color: .blue)
                CollapsedToolButton(icon: "square.and.arrow.up", color: .green)
                CollapsedToolButton(icon: "paintpalette", color: .purple)
                CollapsedToolButton(icon: "clock.arrow.circlepath", color: .orange)
            }

            Spacer()
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(10)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct CollapsedToolButton: View {
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Code Mode

/// Main Code editor view - shows project files
struct CodeView: View {
    @ObservedObject var client: APIClient
    @Binding var selectedPageId: String?

    var body: some View {
        HStack(spacing: 0) {
            // Code editor with selected page's HTML
            if let page = selectedPage {
                CodeEditor(code: .constant(page.html), language: "html")
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a file from sidebar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }

            Divider()

            // Live preview
            if let page = selectedPage {
                WebPreviewPane(html: page.html)
                    .frame(minWidth: 300)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "eye")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Preview")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minWidth: 300, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    private var selectedPage: Page? {
        guard let id = selectedPageId else { return nil }
        return client.pages.first { $0.id == id }
    }
}

// MARK: - Code Editor

struct CodeEditor: View {
    @Binding var code: String
    let language: String

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack {
                Text("index.html")
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)

                Spacer()
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Editor
            ScrollView {
                TextEditor(text: $code)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

// MARK: - Terminal

struct TerminalView: View {
    @Binding var output: String
    @State private var command = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Terminal")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.9))

            // Output
            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.9))

            // Input
            HStack {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)

                TextField("", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        output += "$ \(command)\n"
                        command = ""
                    }
            }
            .padding(8)
            .background(Color.black.opacity(0.9))
        }
    }
}

// MARK: - Web Preview

struct WebPreviewPane: View {
    let html: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            // WebView
            HTMLWebView(html: html)
        }
    }
}

#Preview {
    CodeView(client: APIClient(), selectedPageId: .constant(nil))
        .frame(width: 1000, height: 600)
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
