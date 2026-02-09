import SwiftUI

/// Unified chat view model — streams directly from AI APIs
@MainActor
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var isLoading = false

    let appState: AppState
    private var streamTask: Task<Void, Never>?
    private let agentLoop = AgentLoop()
    private let contentExtractor = ContentExtractor()
    private let chatHistory = ChatHistoryService()
    private let projectUpdater: any ChatProjectUpdating
    private let requestLogger: RequestLogger

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
        let assistantMessage = ChatMessage(role: .assistant, content: "", aiProvider: provider)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        let aiMessages = messages.dropLast().map { msg in
            AIMessage(role: msg.role == .user ? "user" : "assistant", content: msg.content)
        }

        let service = appState.activeAIService
        let promptText = text

        // Use agent loop with tools when a project is selected
        if let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
           let projectName = appState.localProjectName(from: projectId) {
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

    // MARK: - Agent Loop (with tools)

    private func sendWithTools(
        text: String,
        aiMessages: [AIMessage],
        assistantIndex: Int,
        service: any AIService,
        provider: AIProvider,
        projectName: String,
        promptText: String
    ) {
        let executor = ToolExecutor(
            workspace: appState.workspace,
            projectName: projectName
        )

        streamTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                isLoading = false
                messages[assistantIndex].content = "Thinking..."

                let result = try await agentLoop.run(
                    userMessage: text,
                    history: Array(aiMessages.dropLast()), // exclude the current user message
                    systemPrompt: SystemPrompts.websiteBuilderWithTools,
                    service: service,
                    executor: executor
                ) { [weak self] event in
                    guard let self else { return }
                    switch event {
                    case .thinking:
                        break
                    case .toolStart(let name, _):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "\(icon) \(self.toolLabel(name))..."
                    case .toolDone(let name, let summary):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "\(icon) \(self.toolLabel(name)) — done\n\(summary)"
                    case .text:
                        break // final text handled below
                    case .error(let msg):
                        messages[assistantIndex].content = "Error: \(msg)"
                    }
                }

                // Set final response
                messages[assistantIndex].content = result.text.isEmpty ? "Done." : result.text

                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                requestLogger.log(provider: provider, projectId: appState.selectedProjectId, prompt: promptText, totalTime: totalTime, ttft: 0, chunks: 0, chars: result.text.count, inputTokens: result.totalInputTokens, outputTokens: result.totalOutputTokens)

                await projectUpdater.commitAndRefresh(projectName: projectName, commitMessage: text)

                saveChatHistory()
            } catch {
                if !Task.isCancelled {
                    messages[assistantIndex].content = "Error: \(error.localizedDescription)"
                }
                saveChatHistory()
            }
            isStreaming = false
            isLoading = false
        }
    }

    // MARK: - Streaming (no tools)

    private func sendWithStreaming(
        aiMessages: [AIMessage],
        assistantIndex: Int,
        service: any AIService,
        provider: AIProvider,
        promptText: String
    ) {
        streamTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            var firstTokenTime: CFAbsoluteTime?
            var tokenCount = 0

            do {
                let stream = service.generate(
                    messages: aiMessages,
                    systemPrompt: SystemPrompts.websiteBuilder
                )
                isLoading = false
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    if firstTokenTime == nil { firstTokenTime = CFAbsoluteTimeGetCurrent() }
                    tokenCount += 1
                    messages[assistantIndex].content += token
                }
                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                let ttft = firstTokenTime.map { $0 - startTime } ?? totalTime
                let contentLength = messages[assistantIndex].content.count

                await handleGeneratedContent(messages[assistantIndex].content)
                requestLogger.log(provider: provider, projectId: appState.selectedProjectId, prompt: promptText, totalTime: totalTime, ttft: ttft, chunks: tokenCount, chars: contentLength)
                saveChatHistory()
            } catch {
                if !Task.isCancelled {
                    messages[assistantIndex].content += "\n\n[Error: \(error.localizedDescription)]"
                }
                saveChatHistory()
            }
            isStreaming = false
            isLoading = false
        }
    }

    // MARK: - Tool Display Helpers

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "list_files": return "📁"
        case "read_file": return "📄"
        case "create_file": return "📝"
        case "edit_file": return "✏️"
        case "delete_file": return "🗑️"
        case "web_search": return "🔍"
        default: return "🔧"
        }
    }

    private func toolLabel(_ name: String) -> String {
        switch name {
        case "list_files": return "Listing files"
        case "read_file": return "Reading file"
        case "create_file": return "Creating file"
        case "edit_file": return "Editing file"
        case "delete_file": return "Deleting file"
        case "web_search": return "Searching the web"
        default: return name
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
    }

    func resetForProject() {
        stopStreaming()
        messages = []
        loadChatHistory()
    }

    // MARK: - Content Extraction

    private func handleGeneratedContent(_ content: String) async {
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else {
            return // No project — streaming without project, HTML stays in chat only
        }

        do {
            let commitMessage = messages.last(where: { $0.role == .user })?.content ?? "Update"
            if let displayText = try contentExtractor.processAndSave(
                content: content,
                workspace: appState.workspace,
                projectName: projectName
            ) {
                if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                    messages[lastAssistantIndex].content = displayText
                }
            }

            await projectUpdater.commitAndRefresh(projectName: projectName, commitMessage: commitMessage)
        } catch {
#if DEBUG
            print("[Chat] Failed to save HTML: \(error)")
            #endif
        }
    }

    // MARK: - Chat History Persistence

    private var chatHistoryURL: URL? {
        chatHistory.historyURL(
            workspace: appState.workspace,
            projectId: appState.selectedProjectId ?? appState.currentProject?.id,
            projectNameResolver: { appState.localProjectName(from: $0) }
        )
    }

    private func saveChatHistory() {
        guard let url = chatHistoryURL else { return }
        chatHistory.save(messages, to: url)
    }

    private func loadChatHistory() {
        guard let url = chatHistoryURL else { return }
        messages = chatHistory.load(from: url)
    }
}
