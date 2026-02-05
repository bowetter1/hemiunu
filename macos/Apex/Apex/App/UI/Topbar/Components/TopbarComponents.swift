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
    let boss: BossCoordinator

    var body: some View {
        HStack(spacing: 6) {
            // Dot — pulses only while processing
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier(active: boss.isProcessing))

            Text(statusText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }

    private var phaseColor: Color {
        switch boss.phase {
        case .idle: return .secondary
        case .researching: return .blue
        case .building: return boss.isProcessing ? .orange : .green
        }
    }

    private var statusText: String {
        switch boss.phase {
        case .idle:
            return "Idle"
        case .researching:
            return "Researching\u{2026}"
        case .building:
            if boss.isProcessing {
                let active = boss.bosses.filter { $0.service.isProcessing }
                if active.count == 1, let a = active.first {
                    return "\(a.displayName) building\u{2026}"
                }
                return "Building (\(active.count))\u{2026}"
            }
            return "Done"
        }
    }
}

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

// MARK: - Logs Button

struct LogsButton: View {
    let boss: BossCoordinator
    let iconSize: CGFloat
    @State private var isExpanded = false

    private var agentCount: Int {
        (boss.researchBoss != nil ? 1 : 0) + boss.bosses.count
    }

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "list.bullet")
                    .font(.system(size: iconSize, weight: .medium))
                if boss.phase != .idle {
                    Text("\(agentCount)")
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
            LogsPopover(boss: boss)
        }
    }
}

// MARK: - Logs Popover

struct LogsPopover: View {
    let boss: BossCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Activity")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if boss.phase == .idle {
                Text("No activity yet")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if let research = boss.researchBoss {
                            BossRow(instance: research, label: "Research")
                        }
                        ForEach(boss.bosses) { instance in
                            BossRow(instance: instance, label: instance.displayName)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 260, height: 200)
    }
}

struct BossRow: View {
    let instance: BossInstance
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(instance.service.isProcessing ? .orange : .green)
                .frame(width: 5, height: 5)

            Image(systemName: instance.agent.icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(instance.service.isProcessing ? "Running" : "Done")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }
}

// MARK: - Legacy Support

typealias ToolbarButton = IconButton
