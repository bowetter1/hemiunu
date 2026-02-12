import SwiftUI

/// Unified topbar with consistent alignment
struct Topbar: View {
    var appState: AppState
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

    @State private var keyMonitor: Any?
    @State private var showDeployPopover = false
    @State private var showRailwayPopover = false
    @State private var showGitHubPopover = false

    private let height: CGFloat = 38
    private let itemHeight: CGFloat = 26
    private let topInset: CGFloat = 2
    private let iconSize: CGFloat = 12
    private let trafficLightsWidth: CGFloat = 78

    private var showPreviewControls: Bool {
        hasProject && selectedMode == .design
    }

    /// All project groups sorted by most recent
    private var projectGroups: [LocalProjectGroup] {
        LocalProjectGroup.group(appState.localProjects)
    }

    /// Current group's session name
    private var currentSessionName: String? {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return nil }
        let projectName = String(selectedId.dropFirst(6))
        let parts = projectName.components(separatedBy: "/")
        return parts.count == 2 ? parts[0] : projectName
    }

    /// Sibling versions for the current project (e.g. v1, v2, v3 under same session)
    private var versionSiblings: [LocalProject] {
        guard let session = currentSessionName else { return [] }
        return appState.localProjects
            .filter { $0.name.hasPrefix("\(session)/") }
            .sorted { $0.name < $1.name }
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
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Arrow Key Navigation (global via NSEvent monitor)

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept when typing in text fields
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
                return event
            }
            switch event.keyCode {
            case 123: return navigateVersion(-1) ? nil : event  // left
            case 124: return navigateVersion(1) ? nil : event   // right
            case 125: return navigateGroup(1) ? nil : event     // down
            case 126: return navigateGroup(-1) ? nil : event    // up
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func navigateVersion(_ delta: Int) -> Bool {
        let siblings = versionSiblings
        guard siblings.count > 1,
              let selectedId = appState.selectedProjectId,
              let index = siblings.firstIndex(where: { "local:\($0.name)" == selectedId })
        else { return false }
        let newIndex = index + delta
        guard siblings.indices.contains(newIndex) else { return false }
        let project = siblings[newIndex]
        let projectId = "local:\(project.name)"
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.setSelectedProjectId(projectId)
        }
        Task { await appState.loadProject(id: projectId) }
        return true
    }

    private func navigateGroup(_ delta: Int) -> Bool {
        let groups = projectGroups
        guard let session = currentSessionName,
              let idx = groups.firstIndex(where: { $0.sessionName == session })
        else { return false }
        let newIdx = idx + delta
        guard groups.indices.contains(newIdx),
              let target = groups[newIdx].projects.first
        else { return false }
        let projectId = "local:\(target.name)"
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.setSelectedProjectId(projectId)
        }
        Task { await appState.loadProject(id: projectId) }
        return true
    }

    private var leftGroup: some View {
        HStack(spacing: 10) {
            // Sidebar toggle - only show when sidebar is hidden
            if !showSidebar {
                IconButton(icon: "sidebar.left", size: iconSize) {
                    withAnimation(.easeInOut(duration: 0.2)) { showSidebar = true }
                }

                // Version dots — switch between v1/v2/v3 without sidebar
                if versionSiblings.count > 1 {
                    ProjectDots(
                        projects: versionSiblings,
                        selectedProjectId: appState.selectedProjectId,
                        onSelect: { project in
                            let projectId = "local:\(project.name)"
                            appState.setSelectedProjectId(projectId)
                            Task { await appState.loadProject(id: projectId) }
                        }
                    )
                }
            }

            // Version picker on the left (Opus-style)
            if showPreviewControls && !pageVersions.isEmpty {
                TopbarVersionPicker(
                    versions: pageVersions,
                    currentVersion: currentVersion,
                    onSelect: { version in
                        onRestoreVersion?(version)
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
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

            // Show tools button when panel is hidden
            if !showToolsPanel {
                IconButton(icon: "sidebar.right", size: iconSize) {
                    withAnimation(.easeInOut(duration: 0.2)) { showToolsPanel = true }
                }
            }

            topbarDivider

            // Services
            Button { showGitHubPopover.toggle() } label: {
                Image("github")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 1, height: iconSize + 1)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("GitHub")
            .popover(isPresented: $showGitHubPopover) {
                GitHubPopover(appState: appState, chatViewModel: chatViewModel)
            }
            Button { showRailwayPopover.toggle() } label: {
                Image("railway")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 1, height: iconSize + 1)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Deploy (Railway)")
            .popover(isPresented: $showRailwayPopover) {
                RailwayDeployPopover(appState: appState, chatViewModel: chatViewModel)
            }
            Button { } label: {
                Image("supabase")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 1, height: iconSize + 1)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Supabase")
            Button { showDeployPopover.toggle() } label: {
                Image("daytona")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 1, height: iconSize + 1)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Sandbox (Daytona)")
            .popover(isPresented: $showDeployPopover) {
                DeployPopover(appState: appState, chatViewModel: chatViewModel)
            }

            topbarDivider

            // Settings
            TopbarSettingsButton(appState: appState, iconSize: iconSize)

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

    private var topbarDivider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 14)
    }

    // MARK: - Preview Controls

    private var previewControls: some View {
        HStack(spacing: 8) {
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
            .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))

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
                .background(selectedDevice == device ? Color.blue.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 5))
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

// MARK: - Version Dots

private struct ProjectDots: View {
    let projects: [LocalProject]
    let selectedProjectId: String?
    let onSelect: (LocalProject) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(projects) { project in
                let isSelected = selectedProjectId == "local:\(project.name)"
                Circle()
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            onSelect(project)
                        }
                    }
                    .help(project.agentName ?? project.name.components(separatedBy: "/").last ?? project.name)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }
}
