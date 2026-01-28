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
    var onLogout: (() -> Void)? = nil
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

            if isConnected {
                IconButton(icon: "rectangle.portrait.and.arrow.right", size: iconSize) {
                    onLogout?()
                }
                .help("Log out")
            }

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
