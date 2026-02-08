import SwiftUI

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel

    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            messagesView
            Divider().opacity(0.5)
            chatInput
        }
        .onChange(of: appState.currentProject?.id) { oldId, newId in
            if oldId != newId {
                chatViewModel.resetForProject()
                inputText = ""
            }
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
                    } else if chatViewModel.isStreaming {
                        streamingIndicator
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
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(Color.blue.opacity(0.6))
            Text("Forge")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("AI builds your site locally.\nDescribe what you want to build.")
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

    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            PulsingDots()
            Text("Streaming...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 6) {
            // AI Provider selector
            HStack(spacing: 4) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Button {
                        appState.selectedProvider = provider
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 9))
                            Text(provider.shortLabel)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(appState.selectedProvider == provider ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(appState.selectedProvider == provider ? Color.blue : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Describe what to build...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(2...6)
                    .onSubmit { sendMessage() }

                if chatViewModel.isStreaming {
                    Button(action: { chatViewModel.stopStreaming() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 70)
        .glassEffect(.regular, in: .rect(cornerRadius: 10, style: .continuous))
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = inputText
        inputText = ""
        chatViewModel.sendMessage(text)
    }
}

// MARK: - Pulsing Dots Animation

struct PulsingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(index == active ? 0.8 : 0.3))
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
