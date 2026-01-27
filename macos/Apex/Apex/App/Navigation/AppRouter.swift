import SwiftUI

/// Main app router - handles navigation between modes
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @State private var showToolsPanel = true

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            GridBackground()

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
                    showModeSelector: false,
                    inlineTrafficLights: true
                )
                .padding(.horizontal, 0)

                // Content row: left sidebar + main + right sidebar
                HStack(spacing: 0) {
                    // Left sidebar
                    if appState.showSidebar {
                        UnifiedSidebar(
                            appState: appState,
                            webSocket: appState.wsClient,
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
        .onAppear {
            Task {
                await appState.connect()
            }
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
