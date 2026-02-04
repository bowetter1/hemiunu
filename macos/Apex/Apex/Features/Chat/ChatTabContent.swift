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
            chatViewModel.pollClarificationIfNeeded(selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
        }
        .onChange(of: appState.selectedProjectId) { _, newId in
            chatViewModel.boss.selectBossForProject(newId)
        }
        .onChange(of: webSocket.lastEvent) { _, event in
            chatViewModel.handleWebSocketEvent(event, selectedPageId: selectedPageId)
        }
        .onAppear {
            chatViewModel.checkForClarification()
            chatViewModel.pollClarificationIfNeeded(selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
        }
    }

    // MARK: - Messages

    private var messagesView: some View {
        let messages = chatViewModel.messages(for: selectedPageId)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty {
                        if chatViewModel.boss.isActive {
                            bossWelcomeMessage
                        } else {
                            welcomeMessage
                        }
                    }

                    ForEach(messages) { message in
                        SidebarChatBubble(message: message)
                            .id(message.id)
                    }

                    // Show current question if we have unanswered ones (not in boss mode)
                    if !chatViewModel.boss.isActive, let question = chatViewModel.currentQuestion {
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

    private var bossWelcomeMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 28))
                .foregroundColor(Color.purple.opacity(0.6))
            Text("Lab")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("AI agents build your site locally.\nDescribe what you want to build.")
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
            Text(loadingText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }

    private var loadingText: String {
        let boss = chatViewModel.boss
        guard boss.isActive else {
            // Show "Updating page..." when editing an existing project with pages
            if appState.currentProject != nil && !appState.pages.isEmpty {
                return "Updating page..."
            }
            return "Thinking..."
        }
        switch boss.phase {
        case .researching: return "Researching brand..."
        case .building:    return "Building..."
        case .idle:        return "Thinking..."
        }
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

    // MARK: - Input

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Boss toggle button
            Button(action: { chatViewModel.boss.toggle() }) {
                Image(systemName: chatViewModel.boss.isActive ? "brain.head.profile.fill" : "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(chatViewModel.boss.isActive ? .purple : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(chatViewModel.boss.isActive ? "Exit Lab" : "Lab")
            .disabled(!BossService.isAvailable)

            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...6)
                .onSubmit { sendMessage() }

            if chatViewModel.boss.isActive && chatViewModel.boss.isProcessing {
                Button(action: { chatViewModel.boss.stopAll() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(inputText.isEmpty ? .secondary : chatViewModel.boss.isActive ? .purple : .blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
        }
        .padding(12)
        .frame(minHeight: 60)
    }

    private var placeholderText: String {
        if chatViewModel.boss.isActive {
            return "Describe what to build..."
        }

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

// MARK: - Boss File Tree View

/// Displays the files created by the boss in the workspace
struct BossFileTreeView: View {
    let files: [LocalFileInfo]
    let workspaceURL: URL?
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.spring(response: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("Workspace Files")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(files.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(4)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(files.prefix(20)) { file in
                        HStack(spacing: 4) {
                            Image(systemName: file.isDirectory ? "folder" : fileIcon(for: file.path))
                                .font(.system(size: 8))
                                .foregroundColor(file.isDirectory ? .purple : .secondary)
                                .frame(width: 12)
                            Text(file.path)
                                .font(.system(size: 9).monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    if files.count > 20 {
                        Text("... and \(files.count - 20) more files")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 16)

                if let url = workspaceURL {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 9))
                            Text("Open in Finder")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }

    private func fileIcon(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "globe"
        case "css": return "paintbrush"
        case "js", "ts": return "curlybraces"
        case "json": return "doc.text"
        case "md": return "doc.richtext"
        case "png", "jpg", "jpeg", "svg", "gif": return "photo"
        default: return "doc"
        }
    }
}
