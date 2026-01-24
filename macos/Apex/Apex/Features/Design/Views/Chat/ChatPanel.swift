import SwiftUI

/// Chat message model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date

    enum ChatRole {
        case user
        case assistant
    }
}

/// Right-side chat panel for AI conversation
struct ChatPanel: View {
    @ObservedObject var client: APIClient
    var onProjectCreated: ((String) -> Void)? = nil
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false

    private let panelWidth: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            messagesView

            Divider()

            // Input
            chatInput
        }
        .frame(width: panelWidth)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var chatHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("AI Assistant")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let project = client.currentProject {
                Text(statusText(for: project.status))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private func statusText(for status: ProjectStatus) -> String {
        switch status {
        case .brief: return "Starting..."
        case .moodboard: return "Moodboard ready"
        case .layouts: return "Layouts ready"
        case .editing: return "Ready to edit"
        case .done: return "Done"
        case .failed: return "Error"
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Welcome message if no messages
                    if messages.isEmpty {
                        welcomeMessage
                    }

                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if isLoading {
                        loadingIndicator
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(0.5))

            Text("Describe your website")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Text("I'll help you design and build it")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Thinking...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
    }

    private var chatInput: some View {
        HStack(spacing: 10) {
            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(12)
    }

    private var placeholderText: String {
        if let project = client.currentProject {
            switch project.status {
            case .editing, .done:
                return "Describe changes..."
            default:
                return "Waiting for generation..."
            }
        }
        return "Describe your website..."
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText
        inputText = ""

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        messages.append(userMessage)

        isLoading = true

        if let project = client.currentProject,
           project.status == .editing || project.status == .done {
            // Edit existing page
            editPage(instruction: text)
        } else if client.currentProject == nil {
            // Create new project
            createProject(brief: text)
        } else {
            // Project is generating, add waiting message
            isLoading = false
            let response = ChatMessage(
                role: .assistant,
                content: "Please wait while I finish generating...",
                timestamp: Date()
            )
            messages.append(response)
        }
    }

    private func createProject(brief: String) {
        Task {
            do {
                let project = try await client.createProject(brief: brief)
                await MainActor.run {
                    isLoading = false
                    // Notify parent to set selectedProjectId and connect WebSocket
                    onProjectCreated?(project.id)
                    let response = ChatMessage(
                        role: .assistant,
                        content: "I'm creating your website. First, I'll generate some moodboard options for you to choose from...",
                        timestamp: Date()
                    )
                    messages.append(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Sorry, something went wrong: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    messages.append(response)
                }
            }
        }
    }

    private func editPage(instruction: String) {
        guard let project = client.currentProject,
              let page = client.pages.first(where: { $0.layoutVariant == nil }) else {
            isLoading = false
            return
        }

        Task {
            do {
                // 1. Get structured edit instructions from server (small, fast)
                let editResponse = try await client.getStructuredEdit(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction,
                    currentHtml: page.html
                )

                // 2. Apply edits locally (instant!)
                let updatedHtml = HTMLEditor.apply(edits: editResponse.edits, to: page.html)

                // 3. Update local state immediately
                await MainActor.run {
                    if let index = client.pages.firstIndex(where: { $0.id == page.id }) {
                        var updatedPage = client.pages[index]
                        updatedPage = Page(
                            id: updatedPage.id,
                            name: updatedPage.name,
                            html: updatedHtml,
                            layoutVariant: updatedPage.layoutVariant
                        )
                        client.pages[index] = updatedPage
                    }
                }

                // 4. Sync to server in background (non-blocking)
                let _ = try await client.syncPage(
                    projectId: project.id,
                    pageId: page.id,
                    html: updatedHtml
                )

                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: editResponse.explanation.isEmpty
                            ? "Done! I've updated the design."
                            : editResponse.explanation,
                        timestamp: Date()
                    )
                    messages.append(response)
                }
            } catch {
                // Fallback to legacy edit if structured edit fails
                await fallbackLegacyEdit(project: project, page: page, instruction: instruction)
            }
        }
    }

    /// Fallback to full HTML edit if structured edit fails
    private func fallbackLegacyEdit(project: Project, page: Page, instruction: String) async {
        do {
            let updated = try await client.editPage(
                projectId: project.id,
                pageId: page.id,
                instruction: instruction
            )
            await MainActor.run {
                if let index = client.pages.firstIndex(where: { $0.id == page.id }) {
                    client.pages[index] = updated
                }
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Done! I've updated the design.",
                    timestamp: Date()
                )
                messages.append(response)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I couldn't make that change: \(error.localizedDescription)",
                    timestamp: Date()
                )
                messages.append(response)
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(16)

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var backgroundColor: Color {
        message.role == .user ? .blue : Color(nsColor: .windowBackgroundColor)
    }
}
