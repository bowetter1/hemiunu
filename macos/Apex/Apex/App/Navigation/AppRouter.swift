import SwiftUI

/// Main app router - handles navigation between modes
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var client: APIClient
    @State private var showToolsPanel = true

    init() {
        _client = ObservedObject(wrappedValue: AppState.shared.client)
    }

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
                    hasProject: client.currentProject != nil,
                    logs: client.projectLogs,
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
                            client: client,
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
                        client: client,
                        webSocket: appState.wsClient,
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
                    client: client,
                    webSocket: appState.wsClient,
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
                client: client,
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
            CodeModeView(client: client, selectedPageId: $appState.selectedPageId)
        }
    }

    // MARK: - WebSocket

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event,
              let projectId = client.currentProject?.id else { return }

        switch event {
        case .moodboardReady, .layoutsReady, .statusChanged, .pageUpdated:
            appState.scheduleLoadProject(id: projectId)
        case .clarificationNeeded:
            // Also reload project to update status
            appState.scheduleLoadProject(id: projectId)
        case .error(let message):
            appState.errorMessage = message
        default:
            break
        }
    }
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
