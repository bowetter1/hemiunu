import SwiftUI

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject var webSocket: WebSocketManager
    @ObservedObject var chatViewModel: ChatViewModel

    private var client: APIClient { appState.client }
    var selectedPageId: String? = nil
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            messagesView
            Divider()
            chatInput
        }
        .onChange(of: appState.currentProject?.id) { oldId, newId in
            if oldId != newId {
                chatViewModel.resetForProject()
                inputText = ""
            }
            chatViewModel.checkForClarification()
        }
        .onChange(of: webSocket.lastEvent) { _, event in
            chatViewModel.handleWebSocketEvent(event, selectedPageId: selectedPageId)
        }
        .onAppear {
            chatViewModel.checkForClarification()
        }
    }

    private var messagesView: some View {
        let messages = chatViewModel.messages(for: selectedPageId)
        return ScrollViewReader { proxy in
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
                    if let question = chatViewModel.currentQuestion {
                        multiQuestionView(
                            question: question,
                            index: chatViewModel.currentQuestionIndex,
                            total: chatViewModel.clarificationQuestions.count
                        )
                    }

                    if chatViewModel.isLoading {
                        loadingIndicator
                    }
                }
                .padding(12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
            ProgressView().scaleEffect(0.6)
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

            ForEach(question.options, id: \.self) { option in
                Button {
                    chatViewModel.answerQuestion(option, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
                } label: {
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
        if let project = appState.currentProject {
            if project.status == .clarification {
                if chatViewModel.currentQuestion != nil {
                    return "Or type your own answer..."
                }
                return "Type your answer..."
            } else if !appState.pages.isEmpty {
                if let page = chatViewModel.selectedPage(for: selectedPageId) {
                    return "Edit \(page.name)..."
                }
                return "Select a page..."
            } else {
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = inputText
        inputText = ""
        chatViewModel.sendMessage(text, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
    }
}
