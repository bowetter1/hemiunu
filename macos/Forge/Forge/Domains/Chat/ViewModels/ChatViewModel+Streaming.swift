import Foundation

extension ChatViewModel {
    // MARK: - Streaming (no tools)

    func sendWithStreaming(
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
}
