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
            } catch {
                if !Task.isCancelled {
                    messages[assistantIndex].content += "\n\n[Error: \(error.localizedDescription)]"
                }
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
