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

            if showAuthGate {
                LoginView(appState: appState)
            } else {
                // Main layout - ignore safe area to flow into title bar
                VStack(spacing: 0) {
                    // Topbar spanning full width - flows into title bar area
                    Topbar(
                        showSidebar: $appState.showSidebar,
                        showToolsPanel: $showToolsPanel,
                        selectedMode: $appState.currentMode,
                        appearanceMode: $appState.appearanceMode,
                        isConnected: appState.isConnected,
                        hasProject: appState.currentProject != nil,
                        chatViewModel: appState.chatViewModel,
                        onLogout: {
                            appState.logout()
                            appState.clearCurrentProject()
                        },
                        showModeSelector: true,
                        inlineTrafficLights: true,
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

                    // Content area: preview behind, panels overlay
                    Spacer().frame(height: 12)
                    ZStack {
                        // Main content — full width, renders behind panels
                        modeContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 12)

                        // Panels overlay on top
                        HStack(spacing: 0) {
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
                                .transition(.move(edge: .leading).combined(with: .opacity))
                                .padding(.leading, 12)
                            }

                            Spacer()

                            // Right tools panel
                            if showToolsPanel {
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
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .padding(.trailing, 12)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
                .ignoresSafeArea(edges: .top)

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
