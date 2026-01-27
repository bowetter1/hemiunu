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

    // Multi-question clarification state
    @State private var clarificationQuestions: [ClarificationQuestion] = []
    @State private var clarificationAnswers: [String] = []  // answers collected so far

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

    /// The current question index (how many have been answered)
    private var currentQuestionIndex: Int {
        clarificationAnswers.count
    }

    /// The current question to show, if any
    private var currentQuestion: ClarificationQuestion? {
        guard currentQuestionIndex < clarificationQuestions.count else { return nil }
        return clarificationQuestions[currentQuestionIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesView
            Divider()
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
              let clarification = project.clarification else { return }

        // New multi-question format
        if let questions = clarification.questions, !questions.isEmpty {
            if clarificationQuestions.isEmpty {
                clarificationQuestions = questions
                clarificationAnswers = []
            }
        }
        // Legacy single-question fallback
        else if let question = clarification.question,
                let options = clarification.options, !options.isEmpty {
            if clarificationQuestions.isEmpty {
                clarificationQuestions = [ClarificationQuestion(question: question, options: options)]
                clarificationAnswers = []
            }
        }
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

                    // Show current question if we have unanswered ones
                    if let question = currentQuestion {
                        multiQuestionView(
                            question: question,
                            index: currentQuestionIndex,
                            total: clarificationQuestions.count
                        )
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

    private func multiQuestionView(question: ClarificationQuestion, index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question counter + text
            HStack(spacing: 6) {
                Text("\(index + 1)/\(total)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)

                Text(question.question)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(10)

            // Options as buttons
            ForEach(question.options, id: \.self) { option in
                Button(action: { answerQuestion(option) }) {
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
                if currentQuestion != nil {
                    return "Or type your own answer..."
                }
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

    private func answerQuestion(_ option: String) {
        // Show user's choice as a chat message
        let userMessage = ChatMessage(role: .user, content: option, timestamp: Date())
        addMessage(userMessage)

        // Record the answer
        clarificationAnswers.append(option)

        // Check if all questions answered
        if clarificationAnswers.count >= clarificationQuestions.count {
            submitAllAnswers()
        }
    }

    private func submitAllAnswers() {
        guard let projectId = client.currentProject?.id else { return }

        // Combine answers into a structured string for the research phase
        var combined = ""
        for i in 0..<min(clarificationQuestions.count, clarificationAnswers.count) {
            let q = clarificationQuestions[i].question
            let a = clarificationAnswers[i]
            combined += "\(q) → \(a)\n"
        }

        clarificationQuestions = []
        clarificationAnswers = []
        isLoading = true

        Task {
            do {
                let _ = try await client.clarifyProject(projectId: projectId, answer: combined.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Got it! Starting brand research...",
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

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText
        inputText = ""

        // If we're in the middle of answering questions, treat typed input as answer
        if currentQuestion != nil {
            answerQuestion(text)
            return
        }

        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        addMessage(userMessage)
        isLoading = true

        if let project = client.currentProject {
            if project.status == .clarification {
                // Fallback: submit typed answer directly
                submitTypedClarification(text)
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

    private func submitTypedClarification(_ text: String) {
        guard let projectId = client.currentProject?.id else { return }

        clarificationQuestions = []
        clarificationAnswers = []

        Task {
            do {
                let _ = try await client.clarifyProject(projectId: projectId, answer: text)
                await MainActor.run {
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Got it! Starting brand research...",
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

    private func createProject(brief: String) {
        Task {
            do {
                let project = try await client.createProject(brief: brief)
                await MainActor.run {
                    isLoading = false
                    onProjectCreated?(project.id)
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Searching for your brand...",
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

    // MARK: - WebSocket

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event else { return }

        switch event {
        case .clarificationNeeded(let questions):
            isLoading = false
            clarificationQuestions = questions
            clarificationAnswers = []
            let response = ChatMessage(
                role: .assistant,
                content: "Before I start, I have a few questions:",
                timestamp: Date()
            )
            addMessage(response)

        case .moodboardReady:
            clarificationQuestions = []
            clarificationAnswers = []
            let response = ChatMessage(
                role: .assistant,
                content: "Research complete! Check the main area for the brand report.",
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
