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
                // Main layout - ignore safe area to flow into title bar
                VStack(spacing: 0) {
                    // Topbar spanning full width - flows into title bar area
                    Topbar(
                        showSidebar: $appState.showSidebar,
                        selectedMode: $appState.currentMode,
                        appearanceMode: $appState.appearanceMode,
                        isConnected: appState.isConnected,
                        errorMessage: appState.errorMessage,
                        hasProject: appState.currentProject != nil,
                        boss: appState.chatViewModel.boss,
                        onNewProject: {
                            appState.clearCurrentProject()
                            appState.currentMode = .design
                        },
                        onLogout: {
                            appState.logout()
                            appState.clearCurrentProject()
                        },
                        showModeSelector: false,
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
                    .padding(.horizontal, 0)

                    // Content row: left sidebar + main + right sidebar
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
                            .padding(.leading, 16)
                            .padding(.trailing, 8)
                        }

                        // Main content card
                        modeContent
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .padding(.leading, appState.showSidebar ? 0 : 16)
                            .padding(.trailing, 8)

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
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(edges: .top)

                // Centered Mode Selector overlay (centered on entire window)
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
