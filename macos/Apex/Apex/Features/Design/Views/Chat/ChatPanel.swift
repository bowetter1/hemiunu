import SwiftUI

/// Right-side chat panel for AI conversation — pure view, delegates to ChatViewModel
struct ChatPanel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var webSocket: WebSocketManager
    @ObservedObject var chatViewModel: ChatViewModel

    private var client: APIClient { appState.client }
    var selectedPageId: String? = nil
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var inputText = ""

    private let panelWidth: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()

            if let project = appState.currentProject, project.moodboard != nil {
                MoodboardSelector(moodboard: project.moodboard)
                    .padding(12)
                Divider()
            }

            messagesView
            Divider()
            chatInput
        }
        .frame(width: panelWidth)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: appState.currentProject?.id) { _, _ in
            chatViewModel.checkForClarification()
        }
        .onChange(of: webSocket.lastEvent) { _, event in
            chatViewModel.handleWebSocketEvent(event, selectedPageId: selectedPageId)
        }
        .onAppear {
            chatViewModel.checkForClarification()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.blue)
            Text("AI Assistant")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let project = appState.currentProject {
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

    // MARK: - Messages

    private var messagesView: some View {
        let messages = chatViewModel.messages(for: selectedPageId)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        welcomeMessage
                    }

                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    // Multi-question clarification
                    if let question = chatViewModel.currentQuestion {
                        clarificationView(question: question.question, options: question.options)
                    }

                    if chatViewModel.isLoading {
                        loadingIndicator
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
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
                Button {
                    chatViewModel.answerQuestion(option, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
                } label: {
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
            ProgressView().scaleEffect(0.7)
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

    // MARK: - Input

    private var chatInput: some View {
        HStack(spacing: 10) {
            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .onSubmit { sendMessage() }

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
        if let project = appState.currentProject {
            if project.status == .clarification {
                return "Type your answer or select above..."
            } else if !appState.pages.isEmpty {
                if let page = chatViewModel.selectedPage(for: selectedPageId) {
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
        chatViewModel.sendMessage(text, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
    }
}
