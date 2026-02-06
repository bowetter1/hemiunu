import SwiftUI

/// Unified topbar with consistent alignment
struct Topbar: View {
    @Binding var showSidebar: Bool
    @Binding var selectedMode: AppMode
    @Binding var appearanceMode: AppearanceMode
    let isConnected: Bool
    let hasProject: Bool
    let chatViewModel: ChatViewModel
    var onLogout: (() -> Void)? = nil
    var showModeSelector: Bool = true
    var inlineTrafficLights: Bool = false

    // Preview controls (shown in design mode with a project)
    @Binding var selectedDevice: PreviewDevice
    var pageVersions: [PageVersion] = []
    var currentVersion: Int = 1
    var onRestoreVersion: ((Int) -> Void)? = nil
    var onOpenInBrowser: (() -> Void)? = nil

    private let height: CGFloat = 44
    private let itemHeight: CGFloat = 28
    private let topInset: CGFloat = 4
    private let iconSize: CGFloat = 14
    private let trafficLightsWidth: CGFloat = 78

    private var showPreviewControls: Bool {
        hasProject && selectedMode == .design
    }

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
            // Preview controls — version, devices, safari — grouped together
            if showPreviewControls {
                previewControls
            }

            // Activity indicator
            if chatViewModel.isStreaming {
                ActivityPill(chatViewModel: chatViewModel)
                    .frame(height: itemHeight)
            }

            // Logs button
            TopbarLogsButton(chatViewModel: chatViewModel, iconSize: iconSize)

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

    // MARK: - Preview Controls

    private var previewControls: some View {
        HStack(spacing: 8) {
            // Version dots + label (only when versions exist)
            if !pageVersions.isEmpty {
                VersionDots(
                    versions: pageVersions,
                    currentVersion: currentVersion,
                    onSelect: { version in
                        onRestoreVersion?(version)
                    }
                )

                Text("v\(currentVersion)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            // Device picker
            HStack(spacing: 2) {
                deviceButton(.desktop, icon: "desktopcomputer")
                deviceButton(.tablet, icon: "ipad")
                deviceButton(.mobile, icon: "iphone")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            // Open in browser
            Button {
                onOpenInBrowser?()
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: iconSize))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Browser")
        }
    }

    private func deviceButton(_ device: PreviewDevice, icon: String) -> some View {
        Button { selectedDevice = device } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(selectedDevice == device ? .blue : .secondary)
                .frame(width: 28, height: 22)
                .background(selectedDevice == device ? Color.blue.opacity(0.12) : Color.clear)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Appearance

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
