import SwiftUI

extension ChatViewModel {
    // MARK: - Message Management

    func addMessage(_ message: ChatMessage, for pageId: String?) {
        if let pageId = pageId {
            if messagesByPage[pageId] == nil {
                messagesByPage[pageId] = []
            }
            messagesByPage[pageId]?.append(message)
        } else {
            globalMessages.append(message)
        }
    }

    // MARK: - Actions

    /// Main send action — routes to the appropriate handler
    func sendMessage(_ text: String, selectedPageId: String?, onProjectCreated: ((String) -> Void)?) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Boss mode: route all messages to the boss coordinator
        if boss.isActive {
            boss.send(text, setLoading: { [weak self] loading in self?.isLoading = loading })
            return
        }

        // Local project: auto-resume boss mode and send through agent
        if let project = appState.currentProject, project.id.hasPrefix("local:") {
            boss.resumeForLocalProject(project.id)
            boss.send(text, setLoading: { [weak self] loading in self?.isLoading = loading })
            return
        }

        // If answering a multi-question flow, treat as answer
        if currentQuestion != nil {
            answerQuestion(text, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
            return
        }

        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        addMessage(userMessage, for: selectedPageId)
        isLoading = true

        if let project = appState.currentProject {
            if project.status == .clarification {
                submitTypedClarification(text, onProjectCreated: onProjectCreated)
            } else if !appState.pages.isEmpty {
                editPage(instruction: text, selectedPageId: selectedPageId)
            } else {
                isLoading = false
                let response = ChatMessage(role: .assistant, content: "Please wait while I generate...", timestamp: Date())
                addMessage(response, for: selectedPageId)
            }
        } else {
            createProject(brief: text, selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
        }
    }

    /// Answer a clarification question (from button or typed input)
    func answerQuestion(_ option: String, selectedPageId: String?, onProjectCreated: ((String) -> Void)?) {
        let userMessage = ChatMessage(role: .user, content: option, timestamp: Date())
        addMessage(userMessage, for: selectedPageId)

        clarificationAnswers.append(option)

        // Check if all questions answered
        if clarificationAnswers.count >= clarificationQuestions.count {
            submitAllAnswers(selectedPageId: selectedPageId, onProjectCreated: onProjectCreated)
        }
    }

    /// Reset chat state for a new project
    func resetForProject() {
        globalMessages = []
        messagesByPage = [:]
        clarificationQuestions = []
        clarificationAnswers = []
        isLoading = false
    }

    // MARK: - Private

    private func createProject(brief: String, selectedPageId: String?, onProjectCreated: ((String) -> Void)?) {
        Task {
            do {
                let project = try await client.projectService.create(brief: brief)
                appState.currentProject = project
                isLoading = false
                onProjectCreated?(project.id)
                let response = ChatMessage(
                    role: .assistant,
                    content: "Searching for your brand...",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            } catch {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            }
        }
    }

    private func editPage(instruction: String, selectedPageId: String?) {
        guard let project = appState.currentProject,
              let page = selectedPage(for: selectedPageId) else {
            isLoading = false
            let response = ChatMessage(role: .assistant, content: "Select a page first.", timestamp: Date())
            addMessage(response, for: selectedPageId)
            return
        }

        Task {
            do {
                let updated = try await client.pageService.edit(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction
                )

                if let index = appState.pages.firstIndex(where: { $0.id == page.id }) {
                    appState.pages[index] = updated
                }
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Done! Updated to v\(updated.currentVersion).",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            } catch {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            }
        }
    }

    private func submitAllAnswers(selectedPageId: String?, onProjectCreated: ((String) -> Void)?) {
        guard let projectId = appState.currentProject?.id else { return }

        // Combine answers into a structured string
        var combined = ""
        for i in 0..<min(clarificationQuestions.count, clarificationAnswers.count) {
            let q = clarificationQuestions[i].question
            let a = clarificationAnswers[i]
            combined += "\(q) → \(a)\n"
        }

        clarificationQuestions = []
        clarificationAnswers = []
        isLoading = true

        Task {
            do {
                let project = try await client.projectService.clarify(projectId: projectId, answer: combined.trimmingCharacters(in: .whitespacesAndNewlines))
                appState.currentProject = project
                let response = ChatMessage(
                    role: .assistant,
                    content: "Got it! Starting brand research...",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            } catch {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
                addMessage(response, for: selectedPageId)
            }
        }
    }

    private func submitTypedClarification(_ text: String, onProjectCreated: ((String) -> Void)?) {
        guard let projectId = appState.currentProject?.id else { return }

        clarificationQuestions = []
        clarificationAnswers = []

        Task {
            do {
                let project = try await client.projectService.clarify(projectId: projectId, answer: text)
                appState.currentProject = project
                let response = ChatMessage(
                    role: .assistant,
                    content: "Got it! Starting brand research...",
                    timestamp: Date()
                )
                addMessage(response, for: nil)
            } catch {
                isLoading = false
                let response = ChatMessage(
                    role: .assistant,
                    content: "Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
                addMessage(response, for: nil)
            }
        }
    }
}
