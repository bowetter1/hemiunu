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
        let assistantMessage = ChatMessage(role: .assistant, content: "", aiProvider: provider)
        messages.append(assistantMessage)
        let assistantId = assistantMessage.id

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
                    guard let index = messages.firstIndex(where: { $0.id == assistantId }) else { break }
                    messages[index].content += token
                }

                // After streaming completes, handle any generated content
                if let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    handleGeneratedContent(messages[index].content)
                }
            } catch {
                if !Task.isCancelled,
                   let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[index].content += "\n\n[Error: \(error.localizedDescription)]"
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
        let htmlFiles = extractAllHTML(from: content)
        guard !htmlFiles.isEmpty else { return }

        // Determine project name
        guard let projectId = appState.selectedProjectId ?? appState.currentProject?.id,
              let projectName = appState.localProjectName(from: projectId) else {
            // No project selected — create a new one
            createProjectFromHTML(htmlFiles)
            return
        }

        // Save to existing project
        do {
            for (filename, html) in htmlFiles {
                try appState.workspace.writeFile(project: projectName, path: filename, content: html)
            }

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
            appState.errorMessage = "Failed to save HTML: \(error.localizedDescription)"
        }
    }

    /// Create a new local project from generated HTML files
    private func createProjectFromHTML(_ htmlFiles: [(filename: String, html: String)]) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        let projectName = "project-\(timestamp)"

        do {
            _ = try appState.workspace.createProject(name: projectName)
            for (filename, html) in htmlFiles {
                try appState.workspace.writeFile(project: projectName, path: filename, content: html)
            }

            // Init git
            Task {
                _ = try? await appState.workspace.gitInit(project: projectName)
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
            appState.errorMessage = "Failed to create project: \(error.localizedDescription)"
        }
    }

    // MARK: - HTML Extraction

    /// Extract all HTML files from markdown code blocks in AI response.
    /// Looks for filename hints like `<!-- filename.html -->` or ``` headers.
    /// Returns an array of (filename, html) tuples.
    private func extractAllHTML(from content: String) -> [(filename: String, html: String)] {
        var results: [(filename: String, html: String)] = []

        // Match ```html blocks, capturing optional filename from the line before
        let blockPattern = "(?:(?://|<!--|#|/\\*)?\\s*([\\w./-]+\\.html)\\s*(?:-->|\\*/)?\\s*\\n)?```(?:html)?\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: []) else {
            return extractSingleHTML(from: content)
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            let htmlRange = match.range(at: 2)
            guard htmlRange.location != NSNotFound else { continue }
            let html = nsContent.substring(with: htmlRange)

            // Skip non-HTML code blocks
            let trimmedHTML = html.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedHTML.contains("<") && (trimmedHTML.contains("</") || trimmedHTML.lowercased().contains("<!doctype")) else {
                continue
            }

            // Try to extract filename from capture group or from the HTML content
            var filename: String?
            let nameRange = match.range(at: 1)
            if nameRange.location != NSNotFound {
                filename = nsContent.substring(with: nameRange)
            }

            if filename == nil {
                // Try to infer from a <!-- filename --> comment at the start of the HTML
                let commentPattern = "^\\s*<!--\\s*([\\w./-]+\\.html)\\s*-->"
                if let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: []),
                   let commentMatch = commentRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let commentRange = Range(commentMatch.range(at: 1), in: html) {
                    filename = String(html[commentRange])
                }
            }

            results.append((filename: filename ?? "index.html", html: html))
        }

        // Deduplicate: if multiple blocks have the same name, number them
        if results.isEmpty {
            return extractSingleHTML(from: content)
        }

        // If only one result and it's unnamed, keep as index.html
        if results.count == 1 {
            return [(filename: results[0].filename, html: results[0].html)]
        }

        // Ensure unique filenames: if multiple blocks map to index.html, assign names
        var seen: [String: Int] = [:]
        var named: [(filename: String, html: String)] = []
        for (index, item) in results.enumerated() {
            var name = item.filename
            if seen[name] != nil {
                let base = name.replacingOccurrences(of: ".html", with: "")
                name = "\(base)-\(index + 1).html"
            }
            seen[name] = index
            named.append((filename: name, html: item.html))
        }

        return named
    }

    /// Fallback: extract a single HTML block (original behavior)
    private func extractSingleHTML(from content: String) -> [(filename: String, html: String)] {
        let pattern = "```html\\s*\\n([\\s\\S]*?)\\n```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return [(filename: "index.html", html: String(content[range]))]
        }

        // Fallback: look for any ``` block that starts with <!DOCTYPE
        let fallbackPattern = "```\\s*\\n(<!DOCTYPE[\\s\\S]*?)\\n```"
        if let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [.caseInsensitive]),
           let fallbackMatch = fallbackRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let fallbackRange = Range(fallbackMatch.range(at: 1), in: content) {
            return [(filename: "index.html", html: String(content[fallbackRange]))]
        }

        return []
    }
}
