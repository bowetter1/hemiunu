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

    init(appState: AppState) {
        self.appState = appState
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
                logRequest(provider: provider, prompt: promptText, totalTime: totalTime, ttft: 0, chunks: 0, chars: result.text.count, inputTokens: result.totalInputTokens, outputTokens: result.totalOutputTokens)

                await commitWorkspaceVersion(projectName: projectName, message: text)

                // Refresh project state
                appState.setPages(appState.workspace.loadPages(project: projectName))
                appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
                appState.refreshPreview()

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
                logRequest(provider: provider, prompt: promptText, totalTime: totalTime, ttft: ttft, chunks: tokenCount, chars: contentLength, inputTokens: 0, outputTokens: 0)
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

    func selectedPage(for pageId: String?) -> Page? {
        if let pageId = pageId {
            return appState.pages.first { $0.id == pageId }
        }
        return appState.pages.first { $0.layoutVariant == nil }
    }

    // MARK: - Content Extraction

    private func handleGeneratedContent(_ content: String) async {
        guard let html = extractHTML(from: content) else { return }

        // Strip code blocks from chat display — keep only conversational text
        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            let chatText = stripCodeBlocks(from: content).trimmingCharacters(in: .whitespacesAndNewlines)
            messages[lastAssistantIndex].content = chatText.isEmpty
                ? "Site updated."
                : chatText + "\n\n\u{2705} Site updated."
        }

        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else {
            return // No project — streaming without project, HTML stays in chat only
        }

        do {
            try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)
            await commitWorkspaceVersion(
                projectName: projectName,
                message: messages.last(where: { $0.role == .user })?.content ?? "Update"
            )
            appState.setPages(appState.workspace.loadPages(project: projectName))
            appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
            appState.refreshPreview()
        } catch {
            #if DEBUG
            print("[Chat] Failed to save HTML: \(error)")
            #endif
        }
    }

    private func commitWorkspaceVersion(projectName: String, message: String) async {
        _ = try? await appState.workspace.gitCommit(project: projectName, message: message)
        await refreshLocalVersionState(projectName: projectName)
    }

    private func refreshLocalVersionState(projectName: String) async {
        guard let versions = try? await appState.workspace.gitVersions(project: projectName) else { return }
        appState.pageVersions = versions
        appState.currentVersionNumber = versions.last?.version ?? 1
    }

    // MARK: - Chat History Persistence

    private var chatHistoryURL: URL? {
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else { return nil }
        return appState.workspace.projectPath(projectName).appendingPathComponent("chat-history.json")
    }

    private func saveChatHistory() {
        guard let url = chatHistoryURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadChatHistory() {
        guard let url = chatHistoryURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([ChatMessage].self, from: data) {
            messages = loaded
        }
    }

    // MARK: - Request Logging

    private func logRequest(provider: AIProvider, prompt: String, totalTime: Double, ttft: Double, chunks: Int, chars: Int, inputTokens: Int = 0, outputTokens: Int = 0) {
        let logURL = appState.workspace.rootDirectory.appendingPathComponent("ai-log.md")
        let dateStr = ISO8601DateFormatter().string(from: Date())
        let projectName = (appState.selectedProjectId ?? "none").replacingOccurrences(of: "local:", with: "")
        let promptPreview = String(prompt.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        let tokensStr = inputTokens + outputTokens > 0
            ? "\(inputTokens)→\(outputTokens)"
            : "-"
        let costStr: String
        if inputTokens + outputTokens > 0 {
            let cost = (Double(inputTokens) * provider.inputCostPerMillion + Double(outputTokens) * provider.outputCostPerMillion) / 1_000_000
            costStr = String(format: "$%.2f", cost)
        } else {
            costStr = "-"
        }

        let entry = """
        | \(dateStr) | \(provider.shortLabel) | \(provider.modelName) | \(projectName) | \(promptPreview) | \(String(format: "%.1f", ttft))s | \(String(format: "%.1f", totalTime))s | \(chunks) | \(chars) | \(tokensStr) | \(costStr) |

        """

        // Create file with header if it doesn't exist
        if !FileManager.default.fileExists(atPath: logURL.path) {
            let header = """
            # Forge AI Log

            | Timestamp | Provider | Model | Project | Prompt | TTFT | Total | Chunks | Chars | Tokens | Cost |
            |-----------|----------|-------|---------|--------|------|-------|--------|-------|--------|------|

            """
            try? header.write(to: logURL, atomically: true, encoding: .utf8)
        }

        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }

    /// Remove all ``` code blocks from a string, keeping surrounding text
    private func stripCodeBlocks(from content: String) -> String {
        let pattern = "```[\\w]*\\s*\\n[\\s\\S]*?\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
    }

    private func extractHTML(from content: String) -> String? {
        let pattern = "```html\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            let fallbackPattern = "```\\s*\\n(<!DOCTYPE[\\s\\S]*?)\\n```"
            if let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [.caseInsensitive]),
               let fallbackMatch = fallbackRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let fallbackRange = Range(fallbackMatch.range(at: 1), in: content) {
                return String(content[fallbackRange])
            }
            return nil
        }
        return String(content[range])
    }
}
