import Foundation

extension ChatViewModel {
    private struct ProjectPanelState: Codable {
        let activity: PersistedActivityLog
        let checklist: [ChecklistItem]
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
    }

    func startNewChat() {
        stopStreaming()
        messages = []
        agentRawHistory = []
        Task { await appState.bossService.clearCache() }
    }

    func resetForProject() {
        stopStreaming()
        messages = []
        agentRawHistory = []
        // Clear Gemini context cache for previous project
        Task { await appState.bossService.clearCache() }
        loadChatHistory()
        loadAgentHistory()
        loadProjectPanelState()
        // Restore cache state from loaded history
        if !agentRawHistory.isEmpty {
            appState.bossService.cacheMessageCount = 0 // will be set on next updateCache
        }
    }

    // MARK: - Chat History Persistence

    var chatHistoryURL: URL? {
        chatHistory.historyURL(
            workspace: appState.workspace,
            projectId: appState.selectedProjectId ?? appState.currentProject?.id,
            projectNameResolver: { appState.localProjectName(from: $0) }
        )
    }

    func saveChatHistory() {
        guard let url = chatHistoryURL else { return }
        chatHistory.save(messages, to: url)
    }

    func loadChatHistory() {
        guard let url = chatHistoryURL else { return }
        messages = chatHistory.load(from: url)
    }

    // MARK: - Agent History Persistence (full tool call context)

    var agentHistoryURL: URL? {
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else { return nil }
        return appState.workspace.projectPath(projectName).appendingPathComponent("agent-history.json")
    }

    var panelStateURL: URL? {
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else { return nil }
        return appState.workspace.projectPath(projectName).appendingPathComponent("panel-state.json")
    }

    func saveAgentHistory() {
        guard let url = agentHistoryURL else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: agentRawHistory, options: []) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func loadAgentHistory() {
        guard let url = agentHistoryURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }
        agentRawHistory = array
    }

    func saveProjectPanelState() {
        guard !isRestoringProjectPanelState else { return }
        guard let url = panelStateURL else { return }

        let state = ProjectPanelState(
            activity: activityLog.snapshot(),
            checklist: checklist.items
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func loadProjectPanelState() {
        guard let url = panelStateURL else {
            isRestoringProjectPanelState = true
            activityLog.reset()
            checklist.reset()
            isRestoringProjectPanelState = false
            return
        }

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            isRestoringProjectPanelState = true
            activityLog.reset()
            checklist.reset()
            isRestoringProjectPanelState = false
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(ProjectPanelState.self, from: data) else {
            isRestoringProjectPanelState = true
            activityLog.reset()
            checklist.reset()
            isRestoringProjectPanelState = false
            return
        }

        isRestoringProjectPanelState = true
        activityLog.restore(from: state.activity)
        checklist.update(state.checklist)
        isRestoringProjectPanelState = false
    }
}
