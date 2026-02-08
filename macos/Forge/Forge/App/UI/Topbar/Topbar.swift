import SwiftUI

/// Unified topbar with consistent alignment
struct Topbar: View {
    @Binding var showSidebar: Bool
    @Binding var showToolsPanel: Bool
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

    private let height: CGFloat = 38
    private let itemHeight: CGFloat = 26
    private let topInset: CGFloat = 2
    private let iconSize: CGFloat = 12
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
                    .layoutPriority(2)
            }

            // Activity indicator
            ActivityPill(chatViewModel: chatViewModel)
                .frame(height: itemHeight)

            // Show tools button when panel is hidden
            if !showToolsPanel {
                IconButton(icon: "sidebar.right", size: iconSize) {
                    withAnimation(.easeInOut(duration: 0.2)) { showToolsPanel = true }
                }
            }

            // Logs button
            TopbarLogsButton(chatViewModel: chatViewModel, iconSize: iconSize)

            // Divider
            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 16)

            // Appearance toggle
            IconButton(icon: appearanceIcon, size: iconSize) {
                cycleAppearance()
            }
            .help(appearanceMode.displayName)

            if isConnected {
                IconButton(icon: "rectangle.portrait.and.arrow.right", size: iconSize) {
                    onLogout?()
                }
                .help("Log out")
            }
        }
        .frame(height: itemHeight)
    }

    // MARK: - Preview Controls

    private var previewControls: some View {
        HStack(spacing: 8) {
            if !pageVersions.isEmpty {
                TopbarVersionPicker(
                    versions: pageVersions,
                    currentVersion: currentVersion,
                    onSelect: { version in
                        onRestoreVersion?(version)
                    }
                )
                .fixedSize(horizontal: true, vertical: false)

                Text("v\(currentVersion)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }

            // Device width label
            Text(deviceWidthLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Device picker
            HStack(spacing: 2) {
                deviceButton(.desktop, icon: "desktopcomputer")
                deviceButton(.laptop, icon: "laptopcomputer")
                deviceButton(.tablet, icon: "ipad")
                deviceButton(.mobile, icon: "iphone")
            }
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)

            // Open in browser
            IconButton(icon: "safari", size: iconSize) {
                onOpenInBrowser?()
            }
            .help("Open in Browser")
        }
    }

    private var deviceWidthLabel: String {
        switch selectedDevice {
        case .desktop: return "1280"
        case .laptop: return "1024"
        case .tablet: return "768"
        case .mobile: return "375"
        }
    }

    private func deviceButton(_ device: PreviewDevice, icon: String) -> some View {
        Button { selectedDevice = device } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(selectedDevice == device ? .blue : .secondary)
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
