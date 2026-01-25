import SwiftUI

/// Unified topbar with consistent icon sizing and alignment
struct Topbar: View {
    @Binding var showSidebar: Bool
    @Binding var selectedMode: AppMode
    @Binding var appearanceMode: AppearanceMode
    let isConnected: Bool
    let errorMessage: String?
    let hasProject: Bool
    let logs: [LogEntry]

    // Consistent icon size for all toolbar items
    private let iconSize: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left group
            HStack(spacing: 12) {
                // Sidebar toggle
                ToolbarButton(icon: "sidebar.left", size: iconSize) {
                    withAnimation { showSidebar.toggle() }
                }

                // Connection status
                statusDot
            }

            Spacer()

            // Center - Mode selector
            ModeSelector(selectedMode: $selectedMode)

            Spacer()

            // Right group
            HStack(spacing: 12) {
                // Live activity indicator
                if hasProject {
                    ActivityIndicator(logs: logs)
                }

                // Logs
                LogsButton(logs: logs, iconSize: iconSize, hasProject: hasProject)

                // Appearance toggle
                ToolbarButton(icon: appearanceIcon, size: iconSize) {
                    cycleAppearance()
                }
                .help("Appearance: \(appearanceMode.displayName)")
            }
        }
        .frame(height: 32)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        if !isConnected { return .orange }
        if errorMessage != nil { return .red }
        return .green
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

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Selector

struct ModeSelector: View {
    @Binding var selectedMode: AppMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: selectedMode == mode ? .semibold : .regular))
                    }
                    .foregroundColor(selectedMode == mode ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedMode == mode ? Color.blue : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(9)
    }

    private func icon(for mode: AppMode) -> String {
        switch mode {
        case .design: return "paintbrush"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
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
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: iconSize, weight: .regular))
                if hasProject && !logs.isEmpty {
                    Text("\(logs.count)")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                }
            }
            .foregroundColor(.secondary)
            .frame(height: 24)
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
            // Header
            Text("Activity")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Content
            if logs.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(logs) { log in
                            LogRow(log: log)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 280, height: 220)
    }
}

struct LogRow: View {
    let log: LogEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(phaseColor)

            Text(log.message)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    var phaseColor: Color {
        switch log.phase {
        case "brief": return .blue
        case "moodboard": return .purple
        case "layouts": return .orange
        case "editing": return .green
        default: return .secondary
        }
    }
}

// MARK: - Activity Indicator

struct ActivityIndicator: View {
    let logs: [LogEntry]
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            // Show last 3 activities as dots
            ForEach(Array(recentLogs.enumerated()), id: \.offset) { index, log in
                ActivityDot(phase: log.phase, isLatest: index == recentLogs.count - 1)
            }

            // Current activity text
            if let latest = logs.last {
                Text(shortMessage(latest.message))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    private var recentLogs: [LogEntry] {
        Array(logs.suffix(4))
    }

    private func shortMessage(_ message: String) -> String {
        // Truncate long messages
        if message.count > 25 {
            return String(message.prefix(22)) + "..."
        }
        return message
    }
}

struct ActivityDot: View {
    let phase: String
    let isLatest: Bool
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(phaseColor)
            .frame(width: 6, height: 6)
            .scaleEffect(isLatest && pulsing ? 1.3 : 1.0)
            .opacity(isLatest ? 1.0 : 0.5)
            .animation(
                isLatest ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: pulsing
            )
            .onAppear {
                if isLatest { pulsing = true }
            }
    }

    var phaseColor: Color {
        switch phase {
        case "brief": return .blue
        case "clarification": return .orange
        case "moodboard": return .purple
        case "layouts": return .orange
        case "editing": return .green
        default: return .secondary
        }
    }
}

