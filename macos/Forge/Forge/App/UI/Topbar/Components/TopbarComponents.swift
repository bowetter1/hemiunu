import SwiftUI

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Mode Selector

struct ModeSelector: View {
    @Binding var selectedMode: AppMode
    private let itemHeight: CGFloat = 28

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: selectedMode == mode ? .semibold : .regular))
                    }
                    .foregroundColor(selectedMode == mode ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .frame(height: itemHeight)
                    .background(selectedMode == mode ? Color.blue : Color.clear)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 3)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }

    private func icon(for mode: AppMode) -> String {
        switch mode {
        case .design: return "paintbrush.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Activity Pill

struct ActivityPill: View {
    let chatViewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier(active: chatViewModel.isStreaming))

            Text(statusText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.isStreaming)
    }

    private var phaseColor: Color {
        if chatViewModel.isStreaming {
            return chatViewModel.isLoading ? .blue : .orange
        }
        return .secondary
    }

    private var statusText: String {
        if chatViewModel.isStreaming {
            return chatViewModel.isLoading ? "Thinking\u{2026}" : "Streaming\u{2026}"
        }
        return "Idle"
    }
}

// MARK: - Topbar Logs Button

struct TopbarLogsButton: View {
    let chatViewModel: ChatViewModel
    let iconSize: CGFloat
    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "list.bullet")
                    .font(.system(size: iconSize, weight: .medium))
                if !chatViewModel.messages.isEmpty {
                    Text("\(chatViewModel.messages.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .foregroundColor(.secondary)
            .frame(height: 28)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            LogsPopover(messages: chatViewModel.messages)
        }
    }
}

// MARK: - Logs Popover

struct LogsPopover: View {
    let messages: [ChatMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Activity")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if messages.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(messages.suffix(20)) { message in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(message.role == .user ? .blue : .green)
                                    .frame(width: 5, height: 5)

                                Image(systemName: message.role == .user ? "person" : "sparkles")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)

                                Text(message.content.prefix(60) + (message.content.count > 60 ? "\u{2026}" : ""))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    var active: Bool = true
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                isPulsing
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear { isPulsing = active }
            .onChange(of: active) { _, new in isPulsing = new }
    }
}

// MARK: - Legacy Support

typealias ToolbarButton = IconButton
