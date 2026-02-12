import SwiftUI

/// Unified chat view model — streams directly from AI APIs
@MainActor
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var isLoading = false

    let appState: AppState
    let checklist = ChecklistModel()
    let activityLog = ActivityLog()
    var streamTask: Task<Void, Never>?
    var hasFirstBuilderLoaded = false
    let agentLoop = AgentLoop()
    let contentExtractor = ContentExtractor()
    let chatHistory = ChatHistoryService()
    let projectUpdater: any ChatProjectUpdating
    let requestLogger: RequestLogger
    let memoryService = MemoryService()
    /// Full agent conversation history (including tool calls) for context caching
    var agentRawHistory: [[String: Any]] = []

    init(appState: AppState, projectUpdater: (any ChatProjectUpdating)? = nil) {
        self.appState = appState
        self.projectUpdater = projectUpdater ?? AppStateChatProjectCoordinator(appState: appState)
        self.requestLogger = RequestLogger(logDirectory: appState.workspace.rootDirectory)
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isStreaming = true
        isLoading = true

        let provider = appState.selectedProvider
        let displayProvider = appState.hasBossKey ? AIProvider.gemini : provider
        let assistantMessage = ChatMessage(role: .assistant, content: "", aiProvider: displayProvider)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        let aiMessages = messages.dropLast().map { msg in
            AIMessage(role: msg.role == .user ? "user" : "assistant", content: msg.content)
        }

        let service = appState.activeAIService
        let promptText = text

        // Resolve project name (may be nil if no project yet)
        let projectName: String? = {
            if let projectId = appState.selectedProjectId ?? appState.currentProject?.id {
                return appState.localProjectName(from: projectId)
            }
            return nil
        }()

        // Boss mode: always use tools when Gemini key is available
        if appState.hasBossKey {
            sendWithTools(
                text: text,
                aiMessages: Array(aiMessages),
                assistantIndex: assistantIndex,
                service: service,
                provider: provider,
                projectName: projectName ?? "",
                promptText: promptText
            )
        } else if let projectName {
            // Non-Boss tool mode: requires existing project
            sendWithTools(
                text: text,
                aiMessages: Array(aiMessages),
                assistantIndex: assistantIndex,
                service: service,
                provider: provider,
                projectName: projectName,
                promptText: promptText
            )
        } else {
            sendWithStreaming(
                aiMessages: Array(aiMessages),
                assistantIndex: assistantIndex,
                service: service,
                provider: provider,
                promptText: promptText
            )
        }
    }
}
