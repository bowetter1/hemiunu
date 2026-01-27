import SwiftUI

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    var selectedPageId: String? = nil
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var messagesByPage: [String: [ChatMessage]] = [:]
    @State private var globalMessages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var clarificationQuestion: String?
    @State private var clarificationOptions: [String] = []

    private var selectedPage: Page? {
        if let pageId = selectedPageId {
            return client.pages.first { $0.id == pageId }
        }
        return client.pages.first { $0.layoutVariant == nil }
    }

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
            // Messages
            messagesView

            Divider()

            // Input
            chatInput
        }
        .onChange(of: client.currentProject?.id) { _, _ in
            checkForClarification()
        }
        .onChange(of: webSocket.lastEvent) { _, event in
            handleWebSocketEvent(event)
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
        clarificationQuestion = question
        clarificationOptions = options
    }


    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty {
                        welcomeMessage
                    }

                    ForEach(messages) { message in
                        SidebarChatBubble(message: message)
                            .id(message.id)
                    }

                    if let question = clarificationQuestion, !clarificationOptions.isEmpty {
                        clarificationView(question: question, options: clarificationOptions)
                    }

                    if isLoading {
                        loadingIndicator
                    }
                }
                .padding(12)
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
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))

            Text("Chat with AI")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Describe edits or ask questions")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text("Thinking...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }

    private func clarificationView(question: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(10)

            ForEach(options, id: \.self) { option in
                Button(action: { selectClarificationOption(option) }) {
                    Text(option)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...6)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(12)
        .frame(minHeight: 60)
    }

    private var placeholderText: String {
        if let project = client.currentProject {
            if project.status == .clarification {
                return "Type your answer..."
            } else if !client.pages.isEmpty {
                if let page = selectedPage {
                    return "Edit \(page.name)..."
                }
                return "Select a page..."
            } else {
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText
        inputText = ""

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
                let response = ChatMessage(role: .assistant, content: "Please wait while I generate...", timestamp: Date())
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
                    onProjectCreated?(project.id)
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Creating your website. First, I'll generate moodboard options...",
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

    private func editPage(instruction: String) {
        guard let project = client.currentProject,
              let page = selectedPage else {
            isLoading = false
            let response = ChatMessage(role: .assistant, content: "Select a page first.", timestamp: Date())
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
                        content: "Done! Updated to v\(updated.currentVersion).",
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

    private func selectClarificationOption(_ option: String) {
        guard let projectId = client.currentProject?.id else { return }

        let userMessage = ChatMessage(role: .user, content: option, timestamp: Date())
        addMessage(userMessage)

        clarificationQuestion = nil
        clarificationOptions = []
        isLoading = true

        Task {
            do {
                let _ = try await client.clarifyProject(projectId: projectId, answer: option)
                await MainActor.run {
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Got it! Searching for \(option) brand info...",
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

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event else { return }

        switch event {
        case .clarificationNeeded(let question, let options):
            isLoading = false
            clarificationQuestion = question
            clarificationOptions = options
            let response = ChatMessage(
                role: .assistant,
                content: "I need some clarification:",
                timestamp: Date()
            )
            addMessage(response)

        case .moodboardReady:
            clarificationQuestion = nil
            clarificationOptions = []
            let response = ChatMessage(
                role: .assistant,
                content: "Created 3 moodboard options. Select one to continue.",
                timestamp: Date()
            )
            addMessage(response)
            Task {
                if let projectId = client.currentProject?.id {
                    let project = try? await client.getProject(id: projectId)
                    await MainActor.run {
                        client.currentProject = project
                    }
                }
            }

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
}

// MARK: - Sidebar Components

struct SidebarChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 20) }

            Text(message.content)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(message.role == .user ? Color.blue : Color(nsColor: .windowBackgroundColor))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }
}
