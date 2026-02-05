import SwiftUI
import AppKit

/// Main app router - handles navigation between modes
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var designViewModel = DesignViewModel(appState: AppState.shared)
    @State private var showToolsPanel = true

    /// Auth gate — show login when not connected
    private var showAuthGate: Bool {
        !appState.isConnected
    }

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            GridBackground()

            if showAuthGate {
                LoginView(appState: appState)
            } else {
                GlassEffectContainer {
                    // Main layout
                    VStack(spacing: 0) {
                        // Topbar
                        Topbar(
                            showSidebar: $appState.showSidebar,
                            selectedMode: $appState.currentMode,
                            appearanceMode: $appState.appearanceMode,
                            isConnected: appState.isConnected,
                            errorMessage: appState.errorMessage,
                            hasProject: appState.currentProject != nil,
                            isStreaming: appState.chatViewModel.isStreaming,
                            onNewProject: {
                                appState.clearCurrentProject()
                                appState.currentMode = .design
                            },
                            onLogout: {
                                appState.logout()
                                appState.clearCurrentProject()
                            },
                            showModeSelector: false,
                            selectedDevice: $appState.selectedDevice,
                            pageVersions: appState.pageVersions,
                            currentVersion: appState.currentVersionNumber,
                            onRestoreVersion: { version in
                                if let project = appState.currentProject,
                                   let pageId = appState.selectedPageId {
                                    designViewModel.restoreVersion(project: project, pageId: pageId, version: version)
                                }
                            },
                            onOpenInBrowser: {
                                openPreviewInBrowser()
                            }
                        )

                        // Content row: sidebar + main + tools
                        HStack(spacing: 12) {
                            // Left sidebar
                            if appState.showSidebar {
                                SidebarContainer(
                                    appState: appState,
                                    currentMode: appState.currentMode,
                                    selectedProjectId: $appState.selectedProjectId,
                                    selectedPageId: $appState.selectedPageId,
                                    showResearchJSON: $appState.showResearchJSON,
                                    onNewProject: {
                                        appState.clearCurrentProject()
                                        appState.currentMode = .design
                                    },
                                    onClose: {
                                        appState.showSidebar = false
                                    }
                                )
                            }

                            // Main content
                            modeContent
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

                            // Right tools panel
                            ToolsPanel(
                                appState: appState,
                                chatViewModel: appState.chatViewModel,
                                selectedPageId: appState.selectedPageId,
                                isExpanded: $showToolsPanel,
                                onProjectCreated: { projectId in
                                    appState.selectedProjectId = projectId
                                    appState.currentMode = .design
                                },
                                onOpenFloatingChat: {
                                    appState.showFloatingChat = true
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .ignoresSafeArea(edges: .top)

                    // Centered Mode Selector overlay
                    VStack {
                        ModeSelector(selectedMode: $appState.currentMode)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    .zIndex(20)

                    // Floating chat window
                    if appState.showFloatingChat {
                        FloatingChatWindow(
                            appState: appState,
                            chatViewModel: appState.chatViewModel,
                            onClose: {
                                appState.showFloatingChat = false
                            }
                        )
                        .zIndex(30)
                    }
                } // GlassEffectContainer
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

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appState.currentMode {
        case .design:
            DesignView(
                appState: appState,
                viewModel: designViewModel,
                sidebarVisible: appState.showSidebar,
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

        // Inline HTML: write to temp file
        if let pageId = appState.selectedPageId,
           let page = appState.pages.first(where: { $0.id == pageId }),
           !page.html.isEmpty {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "forge-preview-\(UUID().uuidString.prefix(8)).html"
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
