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
                .foregroundStyle(.secondary)
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
    private let itemHeight: CGFloat = 26

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMode = mode
                    }
                } label: {
                    Image(systemName: icon(for: mode))
                        .font(.system(size: 12))
                        .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                        .frame(width: 28, height: 22)
                        .background(selectedMode == mode ? Color.blue.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
    }

    private func icon(for mode: AppMode) -> String {
        switch mode {
        case .design: return "paintbrush.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Topbar Version Picker

struct TopbarVersionPicker: View {
    let versions: [PageVersion]
    let currentVersion: Int
    var onSelect: ((Int) -> Void)? = nil

    private var sortedVersions: [PageVersion] {
        versions.sorted { $0.version < $1.version }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sortedVersions) { item in
                let isSelected = item.version == currentVersion
                Button {
                    onSelect?(item.version)
                } label: {
                    Text("v\(item.version)")
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .frame(width: 28, height: 22)
                        .background(isSelected ? Color.blue.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
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
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
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
            .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if messages.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
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
                                    .foregroundStyle(.secondary)

                                Text(message.content.prefix(60) + (message.content.count > 60 ? "\u{2026}" : ""))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.primary)
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

// MARK: - Topbar Settings Button

struct TopbarSettingsButton: View {
    @Bindable var appState: AppState
    let iconSize: CGFloat
    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Settings")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            settingsPopover
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            // AI Provider picker
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                    .frame(width: 16)

                Text("Provider")
                    .font(.system(size: 11, weight: .medium))

                Spacer()

                Picker("", selection: $appState.selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.shortLabel).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // API key status
            VStack(alignment: .leading, spacing: 6) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(hasKey(for: provider) ? .green : .red.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(provider.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(hasKey(for: provider) ? "Active" : "No key")
                            .font(.system(size: 9))
                            .foregroundStyle(hasKey(for: provider) ? Color.green : Color.secondary.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 240)
    }

    private func hasKey(for provider: AIProvider) -> Bool {
        guard let key = KeychainHelper.load(key: provider.keychainKey) else { return false }
        return !key.isEmpty
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

