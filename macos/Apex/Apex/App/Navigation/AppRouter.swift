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
                        logs: appState.projectLogs,
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
                            UnifiedSidebar(
                                appState: appState,
                                currentMode: appState.currentMode,
                                selectedProjectId: $appState.selectedProjectId,
                                selectedVariantId: $appState.selectedVariantId,
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
                            webSocket: appState.wsClient,
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
                        webSocket: appState.wsClient,
                        chatViewModel: appState.chatViewModel,
                        selectedPageId: appState.selectedPageId,
                        onProjectCreated: { projectId in
                            appState.selectedProjectId = projectId
                            appState.currentMode = .design
                        },
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
        .onChange(of: appState.wsClient.lastEvent) { _, newEvent in
            handleWebSocketEvent(newEvent)
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appState.currentMode {
        case .design:
            DesignView(
                appState: appState,
                wsClient: appState.wsClient,
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
            } catch {}
        }
    }

    // MARK: - WebSocket

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event,
              let projectId = appState.currentProject?.id else {
            if event != nil {
                print("[WS-Handler] Event received but no currentProject: \(String(describing: event))")
            }
            return
        }
        print("[WS-Handler] Handling event: \(event) for project: \(projectId)")

        switch event {
        case .moodboardReady:
            appState.scheduleLoadProject(id: projectId)
            NotificationService.shared.notify(
                title: "Moodboard Ready",
                body: "Brand research and color palette are done."
            )
        case .researchReady:
            appState.scheduleLoadProject(id: projectId)
            NotificationService.shared.notify(
                title: "Research Complete",
                body: "Brand research is done. Review and generate your layout."
            )
        case .layoutsReady(let count):
            appState.scheduleLoadProject(id: projectId)
            NotificationService.shared.notify(
                title: "Layouts Ready",
                body: "\(count) layout\(count == 1 ? "" : "s") generated. Pick your favorite."
            )
        case .statusChanged(let status):
            appState.scheduleLoadProject(id: projectId)
            if status == "done" || status == "editing" {
                NotificationService.shared.notify(
                    title: "Site Ready",
                    body: "Your website has been generated."
                )
            }
        case .pageUpdated:
            appState.scheduleLoadProject(id: projectId)
            NotificationService.shared.notify(
                title: "Page Updated",
                body: "Your edits have been applied."
            )
        case .clarificationNeeded:
            appState.scheduleLoadProject(id: projectId)
            NotificationService.shared.notify(
                title: "Input Needed",
                body: "Apex needs your input to continue."
            )
        case .error(let message):
            appState.errorMessage = message
            NotificationService.shared.notify(
                title: "Error",
                body: message
            )
        default:
            break
        }
    }
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
