import SwiftUI

/// Unified chat view model — streams directly from AI APIs
@MainActor
@Observable
class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isStreaming = false
    var isLoading = false

    let appState: AppState

    /// Current streaming task (cancellable)
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Actions

    /// Main send action — streams directly from the active AI service
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Start streaming response
        isStreaming = true
        isLoading = true

        // Create assistant message placeholder
        let provider = appState.selectedProvider
        var assistantMessage = ChatMessage(role: .assistant, content: "", aiProvider: provider)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        // Build AI message history
        let aiMessages = messages.dropLast().map { msg in
            AIMessage(role: msg.role == .user ? "user" : "assistant", content: msg.content)
        }

        let service = appState.activeAIService

        streamTask = Task {
            do {
                let stream = service.generate(
                    messages: Array(aiMessages),
                    systemPrompt: SystemPrompts.websiteBuilder
                )

                isLoading = false

                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    messages[assistantIndex].content += token
                }

                // After streaming completes, handle any generated content
                handleGeneratedContent(messages[assistantIndex].content)
            } catch {
                if !Task.isCancelled {
                    messages[assistantIndex].content += "\n\n[Error: \(error.localizedDescription)]"
                }
            }
            isStreaming = false
            isLoading = false
        }
    }

    /// Stop the current streaming response
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
    }

    /// Reset chat state for a new project
    func resetForProject() {
        stopStreaming()
        messages = []
    }

    /// Get the selected page
    func selectedPage(for pageId: String?) -> Page? {
        if let pageId = pageId {
            return appState.pages.first { $0.id == pageId }
        }
        return appState.pages.first { $0.layoutVariant == nil }
    }

    // MARK: - Content Extraction

    /// Extract HTML from the AI response and save it to the workspace
    private func handleGeneratedContent(_ content: String) {
        // Extract HTML from markdown code blocks
        guard let html = extractHTML(from: content) else { return }

        // Determine project name
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else {
            // No project selected — create a new one
            createProjectFromHTML(html)
            return
        }

        // Save to existing project
        do {
            try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)

            // Git commit
            Task {
                _ = try? await appState.workspace.gitCommit(
                    project: projectName,
                    message: messages.last(where: { $0.role == .user })?.content ?? "Update"
                )
            }

            // Refresh pages and preview
            appState.setPages(appState.workspace.loadPages(project: projectName))
            appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
            appState.refreshPreview()
        } catch {
            #if DEBUG
            print("[Chat] Failed to save HTML: \(error)")
            #endif
        }
    }

    /// Create a new local project from generated HTML
    private func createProjectFromHTML(_ html: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        let projectName = "project-\(timestamp)"

        do {
            _ = try appState.workspace.createProject(name: projectName)
            try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)

            // Init git
            Task {
                _ = try? await appState.workspace.exec("git init", cwd: appState.workspace.projectPath(projectName))
                _ = try? await appState.workspace.gitCommit(project: projectName, message: "Initial generation")
            }

            // Select the new project
            let projectId = "local:\(projectName)"
            appState.setSelectedProjectId(projectId)
            appState.setLocalPreviewURL(appState.workspace.projectPath(projectName))
            appState.setPages(appState.workspace.loadPages(project: projectName))
            appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
            appState.refreshLocalProjects()
        } catch {
            #if DEBUG
            print("[Chat] Failed to create project: \(error)")
            #endif
        }
    }

    /// Extract HTML from markdown code blocks in AI response
    private func extractHTML(from content: String) -> String? {
        // Look for ```html ... ``` code blocks
        let pattern = "```html\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            // Fallback: look for any ``` ... ``` block that starts with <!DOCTYPE or <html
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
