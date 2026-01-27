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
                    .background(selectedMode == mode ? Color.orange : Color.clear)
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
    let logs: [LogEntry]

    var body: some View {
        HStack(spacing: 6) {
            // Pulsing dot
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())

            // Latest message
            if let latest = logs.last {
                Text(truncate(latest.message, to: 20))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }

    private var phaseColor: Color {
        guard let phase = logs.last?.phase else { return .secondary }
        switch phase {
        case "brief": return .blue
        case "moodboard": return .purple
        case "layouts": return .orange
        case "editing": return .green
        default: return .secondary
        }
    }

    private func truncate(_ text: String, to length: Int) -> String {
        text.count > length ? String(text.prefix(length - 1)) + "\u{2026}" : text
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Logs Button

struct LogsButton: View {
    let logs: [LogEntry]
    let iconSize: CGFloat
    let hasProject: Bool
    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "list.bullet")
                    .font(.system(size: iconSize, weight: .medium))
                if hasProject && !logs.isEmpty {
                    Text("\(logs.count)")
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
            LogsPopover(logs: logs)
        }
    }
}

// MARK: - Logs Popover

struct LogsPopover: View {
    let logs: [LogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Activity")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if logs.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { log in
                            LogRow(log: log)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 260, height: 200)
    }
}

struct LogRow: View {
    let log: LogEntry

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phaseColor)
                .frame(width: 5, height: 5)

            Text(log.message)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }

    private var phaseColor: Color {
        switch log.phase {
        case "brief": return .blue
        case "moodboard": return .purple
        case "layouts": return .orange
        case "editing": return .green
        default: return .secondary
        }
    }
}

// MARK: - Legacy Support

typealias ToolbarButton = IconButton
