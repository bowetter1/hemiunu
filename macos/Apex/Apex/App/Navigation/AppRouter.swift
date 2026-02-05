import SwiftUI
import AppKit

/// Main app router - Liquid Glass layout with NavigationSplitView
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var designViewModel = DesignViewModel(appState: AppState.shared)
    @State private var showToolsPanel = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    /// Auth gate — show login when not connected
    private var showAuthGate: Bool {
        !appState.isConnected
    }

    private var showPreviewControls: Bool {
        appState.currentProject != nil && appState.currentMode == .design
    }

    private var boss: BossCoordinator {
        appState.chatViewModel.boss
    }

    var body: some View {
        Group {
            if showAuthGate {
                LoginView(appState: appState)
            } else {
                mainContent
            }
        }
        .onAppear {
            Task {
                await appState.connect()
            }
        }
        .onChange(of: appState.isConnected) { _, newValue in
#if DEBUG
            print("[Auth] isConnected changed -> \(newValue)")
#endif
        }
        .onChange(of: appState.selectedProjectId) { _, newId in
            if let id = newId {
                Task {
                    await appState.loadProject(id: id)
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar — automatic Liquid Glass treatment
            SidebarContainer(
                appState: appState,
                currentMode: appState.currentMode,
                selectedProjectId: $appState.selectedProjectId,
                selectedPageId: $appState.selectedPageId,
                showResearchJSON: $appState.showResearchJSON,
                onNewProject: {
                    appState.clearCurrentProject()
                    appState.currentMode = .design
                }
            )
        } detail: {
            // Main content area
            modeContent
                .backgroundExtensionEffect()
                .overlay(alignment: .bottom) {
                    if appState.showFloatingChat {
                        FloatingChatWindow(
                            appState: appState,
                            chatViewModel: appState.chatViewModel,
                            onClose: {
                                appState.showFloatingChat = false
                            }
                        )
                        .padding(.bottom, 16)
                    }
                }
        }
        .inspector(isPresented: $showToolsPanel) {
            ToolsPanel(
                appState: appState,
                chatViewModel: appState.chatViewModel,
                selectedPageId: appState.selectedPageId,
                onProjectCreated: { projectId in
                    appState.selectedProjectId = projectId
                    appState.currentMode = .design
                },
                onOpenFloatingChat: {
                    appState.showFloatingChat = true
                }
            )
            .inspectorColumnWidth(min: 280, ideal: 300, max: 340)
        }
        .toolbar {
            toolbarContent
        }
    }

    // MARK: - Toolbar (Liquid Glass)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Center: Mode selector
        ToolbarItem(placement: .principal) {
            ModeSelector(selectedMode: $appState.currentMode)
        }

        // Preview controls (design mode with project)
        ToolbarItemGroup(placement: .primaryAction) {
            if showPreviewControls {
                if !appState.pageVersions.isEmpty {
                    VersionDots(
                        versions: appState.pageVersions,
                        currentVersion: appState.currentVersionNumber,
                        onSelect: { version in
                            if let project = appState.currentProject,
                               let pageId = appState.selectedPageId {
                                designViewModel.restoreVersion(project: project, pageId: pageId, version: version)
                            }
                        }
                    )

                    Text("v\(appState.currentVersionNumber)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                devicePicker

                Button {
                    openPreviewInBrowser()
                } label: {
                    Image(systemName: "safari")
                }
                .help("Open in Browser")
            }
        }

        // Activity + logs
        ToolbarItemGroup(placement: .automatic) {
            if boss.phase != .idle {
                ActivityPill(boss: boss)
            }

            LogsButton(boss: boss, iconSize: 14)
        }

        // Account + appearance
        ToolbarItemGroup(placement: .secondaryAction) {
            if appState.isConnected {
                Button {
                    appState.logout()
                    appState.clearCurrentProject()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .help("Log out")
            }

            Button {
                cycleAppearance()
            } label: {
                Image(systemName: appearanceIcon)
            }
            .help(appState.appearanceMode.displayName)
        }
    }

    // MARK: - Device Picker

    private var devicePicker: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                deviceButton(.desktop, icon: "desktopcomputer")
                deviceButton(.tablet, icon: "ipad")
                deviceButton(.mobile, icon: "iphone")
            }
        }
    }

    private func deviceButton(_ device: PreviewDevice, icon: String) -> some View {
        Button {
            appState.selectedDevice = device
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
        }
        .buttonStyle(appState.selectedDevice == device ? .glassProminent : .glass)
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appState.currentMode {
        case .design:
            DesignView(
                appState: appState,
                viewModel: designViewModel,
                sidebarVisible: columnVisibility != .detailOnly,
                toolsPanelVisible: showToolsPanel,
                selectedPageId: appState.selectedPageId,
                showResearchJSON: appState.showResearchJSON,
                onProjectCreated: { projectId in
                    Task {
                        await appState.loadProject(id: projectId)
                    }
                }
            )
        case .code:
            CodeModeView(appState: appState, selectedPageId: $appState.selectedPageId)
        }
    }

    // MARK: - Appearance

    private var appearanceIcon: String {
        switch appState.appearanceMode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private func cycleAppearance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch appState.appearanceMode {
            case .system: appState.appearanceMode = .light
            case .light: appState.appearanceMode = .dark
            case .dark: appState.appearanceMode = .system
            }
        }
    }

    // MARK: - Open in Browser

    private func openPreviewInBrowser() {
        // Local file: open directly
        if let localURL = appState.localPreviewURL {
            if let projectName = appState.currentProject.flatMap({ appState.localProjectName(from: $0.id) }),
               let mainHTML = appState.workspace.findMainHTML(project: projectName) {
                let fileURL = localURL.appendingPathComponent(mainHTML)
                NSWorkspace.shared.open(fileURL)
            } else {
                NSWorkspace.shared.open(localURL)
            }
            return
        }

        // Sandbox preview: open URL
        if let project = appState.currentProject,
           let previewUrl = project.sandboxPreviewUrl,
           let url = URL(string: previewUrl) {
            NSWorkspace.shared.open(url)
            return
        }

        // Inline HTML: write to temp file
        if let pageId = appState.selectedPageId,
           let page = appState.pages.first(where: { $0.id == pageId }),
           !page.html.isEmpty {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "apex-preview-\(UUID().uuidString.prefix(8)).html"
            let fileURL = tempDir.appendingPathComponent(fileName)
            do {
                try page.html.write(to: fileURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(fileURL)
            } catch {
                appState.errorMessage = "Failed to open preview: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
