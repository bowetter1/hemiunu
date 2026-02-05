import SwiftUI

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel

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
        }
        .onChange(of: appState.selectedProjectId) { _, newId in
            chatViewModel.boss.selectBossForProject(newId)
        }
    }

    // MARK: - Messages

    private var messagesView: some View {
        let messages = chatViewModel.messages
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

                    if chatViewModel.isLoading {
                        loadingIndicator
                    } else if chatViewModel.boss.isProcessing {
                        workingIndicator
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

    private var workingIndicator: some View {
        HStack(spacing: 6) {
            PulsingDots()
            Text(workingText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(10)
    }

    private var workingText: String {
        switch chatViewModel.boss.phase {
        case .researching: return "Researching..."
        case .building:    return "Building files..."
        case .idle:        return "Working..."
        }
    }

    private var loadingText: String {
        switch chatViewModel.boss.phase {
        case .researching: return "Researching brand..."
        case .building:    return "Building..."
        case .idle:        return "Thinking..."
        }
    }

    // MARK: - Input

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Describe what to build...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...6)
                .onSubmit { sendMessage() }

            if chatViewModel.boss.isProcessing {
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
                        .foregroundColor(inputText.isEmpty ? .secondary : .purple)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
        }
        .padding(12)
        .frame(minHeight: 60)
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = inputText
        inputText = ""
        chatViewModel.sendMessage(text)
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

// MARK: - Pulsing Dots Animation

struct PulsingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.purple.opacity(index == active ? 0.8 : 0.3))
                    .frame(width: 5, height: 5)
                    .scaleEffect(index == active ? 1.2 : 1.0)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    active = (active + 1) % 3
                }
            }
        }
    }
}
