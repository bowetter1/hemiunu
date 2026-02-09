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

        // Resolve project name (may be nil if no project yet)
        let projectName: String? = {
            if let projectId = appState.selectedProjectId ?? appState.currentProject?.id {
                return appState.localProjectName(from: projectId)
            }
            return nil
        }()

        // Boss mode: always use tools when Claude key is available
        if appState.hasClaudeKey {
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
        // Boss mode: use Claude as orchestrator when API key is available
        let useBossMode = appState.hasClaudeKey
        let bossService: any AIService = useBossMode ? appState.claudeService : service
        let bossProvider: AIProvider = useBossMode ? .claude : provider

        let executor: any ToolExecuting
        let bossExecutor: BossToolExecutor?
        let systemPrompt: String
        let tools: [[String: Any]]?

        if useBossMode {
            let boss = BossToolExecutor(
                workspace: appState.workspace,
                projectName: projectName,
                serviceResolver: { [weak appState] provider in
                    appState?.resolveService(for: provider) ?? service
                },
                onChecklistUpdate: { [weak self] items in
                    self?.checklist.update(items)
                },
                onSubAgentEvent: { [weak self] role, event in
                    guard let self else { return }
                    switch event {
                    case .toolStart(let name, _):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "[\(role.rawValue)] \(icon) \(self.toolLabel(name))..."
                    case .toolDone(let name, let summary):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "[\(role.rawValue)] \(icon) \(self.toolLabel(name)) — done\n\(summary)"
                    default:
                        break
                    }
                },
                onProjectCreate: { [weak self] name in
                    guard let appState = self?.appState else { return }
                    let projectId = "local:\(name)"
                    appState.setSelectedProjectId(projectId)
                    appState.setLocalPreviewURL(appState.workspace.projectPath(name))
                    appState.setLocalFiles(appState.workspace.listFiles(project: name))
                    appState.refreshLocalProjects()
                    Task { _ = try? await appState.workspace.ensureGitRepository(project: name) }
                }
            )
            executor = boss
            bossExecutor = boss
            let hasProject = !projectName.isEmpty
            systemPrompt = BossSystemPrompts.boss + (hasProject
                ? "\n\nCONTEXT: Project '\(projectName)' already exists. Do NOT call create_project."
                : "\n\nCONTEXT: No project exists yet. You MUST call create_project first.")
            tools = ForgeTools.bossAnthropicFormat()
        } else {
            executor = ToolExecutor(
                workspace: appState.workspace,
                projectName: projectName
            )
            bossExecutor = nil
            systemPrompt = SystemPrompts.websiteBuilderWithTools
            tools = nil
        }

        streamTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                isLoading = false
                messages[assistantIndex].content = useBossMode ? "Planning..." : "Thinking..."
                if useBossMode { checklist.reset() }

                let result = try await agentLoop.run(
                    userMessage: text,
                    history: Array(aiMessages.dropLast()), // exclude the current user message
                    systemPrompt: systemPrompt,
                    service: bossService,
                    executor: executor,
                    tools: tools
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
                requestLogger.log(provider: bossProvider, projectId: appState.selectedProjectId, prompt: promptText, totalTime: totalTime, ttft: 0, chunks: 0, chars: result.text.count, inputTokens: result.totalInputTokens, outputTokens: result.totalOutputTokens)

                // Use the (potentially updated) project name from BossToolExecutor
                let finalProjectName = bossExecutor?.projectName ?? projectName
                if !finalProjectName.isEmpty {
                    await projectUpdater.commitAndRefresh(projectName: finalProjectName, commitMessage: text)
                }

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
        case "delegate_task": return "👥"
        case "update_checklist": return "📋"
        case "create_project": return "🏗️"
        case "build_version": return "🏗️"
        case "take_screenshot": return "📸"
        case "review_screenshot": return "🔎"
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
        case "delegate_task": return "Delegating task"
        case "update_checklist": return "Updating checklist"
        case "create_project": return "Creating project"
        case "build_version": return "Building version"
        case "take_screenshot": return "Taking screenshot"
        case "review_screenshot": return "Reviewing screenshot"
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
