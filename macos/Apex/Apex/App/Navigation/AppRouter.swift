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
            // Sidebar
            if appState.showSidebar {
                ProjectsSidebar(
                    client: client,
                    selectedProjectId: $appState.selectedProjectId,
                    selectedVariantId: $appState.selectedVariantId,
                    selectedPageId: $appState.selectedPageId,
                    onNewProject: {
                        appState.clearCurrentProject()
                    }
                )

                Divider()
            }

            // Main content area
            ZStack(alignment: .top) {
                // Background
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                GridBackground()

                // Content layer with chat panel
                VStack(spacing: 0) {
                    // Spacer for topbar
                    Spacer()
                        .frame(height: 60)

                    // Main content + chat panel
                    HStack(spacing: 0) {
                        // Mode content (preview)
                        modeContent
                            .frame(maxWidth: .infinity)

                        // Chat panel (Design mode only)
                        if appState.currentMode == .design {
                            Divider()
                            ChatPanel(
                                client: client,
                                webSocket: appState.wsClient,
                                selectedPageId: appState.selectedPageId
                            ) { projectId in
                                // Set selectedProjectId to trigger WebSocket connection
                                appState.selectedProjectId = projectId
                            }
                        }
                    }
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
                    .padding(.horizontal)

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
        case .chat:
            ChatView()
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

// MARK: - Chat Mode

/// A chat message
struct Message: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role {
        case user
        case assistant
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

/// Chat view with message list and input
struct ChatView: View {
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            ChatInput(text: $inputText, onSend: sendMessage)
                .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = Message(role: .user, content: inputText)
        messages.append(userMessage)
        inputText = ""

        // Simulate AI response
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = Message(role: .assistant, content: "This is a placeholder response. The AI integration is coming soon!")
            messages.append(response)
            isLoading = false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color(nsColor: .controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant { Spacer() }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Chat Input

struct ChatInput: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(text.isEmpty ? .gray : .blue)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 0.3 : 1)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { animating = true }
    }
}

// MARK: - Code Mode

/// Main Code editor view - shows project files
struct CodeView: View {
    @ObservedObject var client: APIClient
    @Binding var selectedPageId: String?

    var body: some View {
        HStack(spacing: 0) {
            // File explorer - show project pages as files
            CodeFileExplorer(
                pages: client.pages,
                selectedPageId: $selectedPageId
            )
            .frame(width: 200)

            Divider()

            // Code editor with selected page's HTML
            if let page = selectedPage {
                CodeEditor(code: .constant(page.html), language: "html")
            } else {
                VStack {
                    Spacer()
                    Text("Select a file to view code")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }

            Divider()

            // Live preview
            if let page = selectedPage {
                WebPreviewPane(html: page.html)
                    .frame(minWidth: 300)
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .frame(minWidth: 300)
            }
        }
    }

    private var selectedPage: Page? {
        guard let id = selectedPageId else { return nil }
        return client.pages.first { $0.id == id }
    }
}

// MARK: - Code File Explorer

struct CodeFileExplorer: View {
    let pages: [Page]
    @Binding var selectedPageId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // File list from pages
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if pages.isEmpty {
                        Text("No files")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(pages) { page in
                            CodeFileRow(
                                page: page,
                                isSelected: selectedPageId == page.id,
                                onSelect: { selectedPageId = page.id }
                            )
                        }
                    }
                }
                .padding(8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct CodeFileRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var fileName: String {
        let name = page.name.lowercased().replacingOccurrences(of: " ", with: "-")
        return "\(name).html"
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
    ChatView()
        .frame(width: 500, height: 600)
}

#Preview {
    CodeView(client: APIClient(), selectedPageId: .constant(nil))
        .frame(width: 1000, height: 600)
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
