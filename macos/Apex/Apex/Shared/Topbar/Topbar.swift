import SwiftUI

/// Unified topbar with consistent alignment
struct Topbar: View {
    @Binding var showSidebar: Bool
    @Binding var selectedMode: AppMode
    @Binding var appearanceMode: AppearanceMode
    let isConnected: Bool
    let errorMessage: String?
    let hasProject: Bool
    let logs: [LogEntry]
    var onNewProject: (() -> Void)? = nil
    var showModeSelector: Bool = true
    var inlineTrafficLights: Bool = false

    private let height: CGFloat = 44
    private let itemHeight: CGFloat = 28
    private let topInset: CGFloat = 4
    private let iconSize: CGFloat = 14
    private let trafficLightsWidth: CGFloat = 78

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Space for traffic lights when inline
            if inlineTrafficLights {
                Color.clear
                    .frame(width: trafficLightsWidth)
            }

            // Left group
            leftGroup

            Spacer()

            // Center - Mode selector
            if showModeSelector {
                ModeSelector(selectedMode: $selectedMode)
                    .frame(height: itemHeight)
            }

            Spacer()

            // Right group
            rightGroup
        }
        .frame(height: height, alignment: .top)
        .padding(.top, topInset)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var leftGroup: some View {
        HStack(spacing: 10) {
            // Sidebar toggle - only show when sidebar is hidden
            if !showSidebar {
                IconButton(icon: "sidebar.left", size: iconSize) {
                    withAnimation(.easeInOut(duration: 0.2)) { showSidebar = true }
                }
            }
        }
        .frame(height: itemHeight)
    }

    private var rightGroup: some View {
        HStack(spacing: 8) {
            // Activity indicator
            if hasProject && !logs.isEmpty {
                ActivityPill(logs: logs)
                    .frame(height: itemHeight)
            }

            // Logs button
            LogsButton(logs: logs, iconSize: iconSize, hasProject: hasProject)

            // Divider
            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 16)

            // Appearance toggle
            IconButton(icon: appearanceIcon, size: iconSize) {
                cycleAppearance()
            }
            .help(appearanceMode.displayName)
        }
        .frame(height: itemHeight)
    }

    private var appearanceIcon: String {
        switch appearanceMode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    private func cycleAppearance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch appearanceMode {
            case .system: appearanceMode = .light
            case .light: appearanceMode = .dark
            case .dark: appearanceMode = .system
            }
        }
    }
}

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
        text.count > length ? String(text.prefix(length - 1)) + "…" : text
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
