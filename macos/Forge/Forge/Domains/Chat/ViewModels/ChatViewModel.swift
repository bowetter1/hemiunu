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
                handleGeneratedContent(messages[assistantIndex].content)
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

    private func handleGeneratedContent(_ content: String) {
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
            createProjectFromHTML(html)
            return
        }

        do {
            try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)
            Task {
                _ = try? await appState.workspace.gitCommit(
                    project: projectName,
                    message: messages.last(where: { $0.role == .user })?.content ?? "Update"
                )
            }
            appState.setPages(appState.workspace.loadPages(project: projectName))
            appState.setLocalFiles(appState.workspace.listFiles(project: projectName))
            appState.refreshPreview()
        } catch {
            #if DEBUG
            print("[Chat] Failed to save HTML: \(error)")
            #endif
        }
    }

    private func createProjectFromHTML(_ html: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        let projectName = "project-\(timestamp)"

        do {
            _ = try appState.workspace.createProject(name: projectName)
            try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)
            Task {
                _ = try? await appState.workspace.exec("git init", cwd: appState.workspace.projectPath(projectName))
                _ = try? await appState.workspace.gitCommit(project: projectName, message: "Initial generation")
            }
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
