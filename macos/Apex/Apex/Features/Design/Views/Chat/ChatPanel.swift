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
    @ObservedObject var webSocket: WebSocketManager
    var selectedPageId: String? = nil
    var onProjectCreated: ((String) -> Void)? = nil

    // Messages stored per page (pageId -> messages)
    @State private var messagesByPage: [String: [ChatMessage]] = [:]
    // Messages for when no page is selected (new project flow)
    @State private var globalMessages: [ChatMessage] = []

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var clarificationQuestion: String?
    @State private var clarificationOptions: [String] = []

    private let panelWidth: CGFloat = 320

    // Get the selected page or fall back to first non-layout page
    private var selectedPage: Page? {
        if let pageId = selectedPageId {
            return client.pages.first { $0.id == pageId }
        }
        return client.pages.first { $0.layoutVariant == nil }
    }

    // Current messages based on selected page
    private var messages: [ChatMessage] {
        if let pageId = selectedPageId {
            return messagesByPage[pageId] ?? []
        }
        return globalMessages
    }

    private func addMessage(_ message: ChatMessage) {
        if let pageId = selectedPageId {
            if messagesByPage[pageId] == nil {
                messagesByPage[pageId] = []
            }
            messagesByPage[pageId]?.append(message)
        } else {
            globalMessages.append(message)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Brand & Inspiration panel (if project has research data)
            if let project = client.currentProject, project.moodboard != nil {
                MoodboardSelector(moodboard: project.moodboard)
                    .padding(12)

                Divider()
            }

            // Messages
            messagesView

            Divider()

            // Input
            chatInput
        }
        .frame(width: panelWidth)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: client.currentProject?.id) { _, _ in
            // When project changes, check if it needs clarification
            checkForClarification()
        }
        .onAppear {
            checkForClarification()
        }
    }

    private func checkForClarification() {
        guard let project = client.currentProject,
              project.status == .clarification,
              let clarification = project.clarification,
              let question = clarification.question,
              let options = clarification.options,
              !options.isEmpty else {
            return
        }

        // Show clarification UI
        clarificationQuestion = question
        clarificationOptions = options
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
        case .clarification: return "Need info"
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

                    // Clarification options
                    if let question = clarificationQuestion, !clarificationOptions.isEmpty {
                        clarificationView(question: question, options: clarificationOptions)
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
            .onChange(of: webSocket.lastEvent) { _, event in
                handleWebSocketEvent(event)
            }
        }
    }

    private func clarificationView(question: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)

            ForEach(options, id: \.self) { option in
                Button(action: {
                    selectClarificationOption(option)
                }) {
                    Text(option)
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event else { return }

        switch event {
        case .clarificationNeeded(let question, let options):
            isLoading = false
            clarificationQuestion = question
            clarificationOptions = options
            let response = ChatMessage(
                role: .assistant,
                content: "I need some clarification before I continue:",
                timestamp: Date()
            )
            addMessage(response)

        case .moodboardReady:
            clarificationQuestion = nil
            clarificationOptions = []
            let response = ChatMessage(
                role: .assistant,
                content: "I've analyzed the brand and selected the best color palette. Now generating layouts...",
                timestamp: Date()
            )
            addMessage(response)

        case .error(let message):
            isLoading = false
            let response = ChatMessage(
                role: .assistant,
                content: "Error: \(message)",
                timestamp: Date()
            )
            addMessage(response)

        default:
            break
        }
    }

    private func selectClarificationOption(_ option: String) {
        guard let projectId = client.currentProject?.id else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: option, timestamp: Date())
        addMessage(userMessage)

        // Clear clarification UI
        clarificationQuestion = nil
        clarificationOptions = []
        isLoading = true

        Task {
            do {
                let _ = try await client.clarifyProject(projectId: projectId, answer: option)
                await MainActor.run {
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Got it! Now searching for \(option) brand info...",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
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
            if project.status == .clarification {
                return "Type your answer or select above..."
            } else if !client.pages.isEmpty {
                if let page = selectedPage {
                    return "Edit \(page.name)..."
                }
                return "Select a page in sidebar to edit..."
            } else {
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
        addMessage(userMessage)

        isLoading = true

        if let project = client.currentProject {
            if project.status == .clarification {
                selectClarificationOption(text)
            } else if !client.pages.isEmpty {
                editPage(instruction: text)
            } else {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Please wait while I finish generating...",
                    timestamp: Date()
                )
                addMessage(response)
            }
        } else {
            createProject(brief: text)
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
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Sorry, something went wrong: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            }
        }
    }

    private func editPage(instruction: String) {
        guard let project = client.currentProject,
              let page = selectedPage else {
            isLoading = false
            let response = ChatMessage(
                role: .assistant,
                content: "Please select a page from the sidebar first.",
                timestamp: Date()
            )
            addMessage(response)
            return
        }

        Task {
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
                        content: "Done! Updated to version \(updated.currentVersion).",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Sorry, I couldn't make that change: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
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
                addMessage(response)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I couldn't make that change: \(error.localizedDescription)",
                    timestamp: Date()
                )
                addMessage(response)
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
