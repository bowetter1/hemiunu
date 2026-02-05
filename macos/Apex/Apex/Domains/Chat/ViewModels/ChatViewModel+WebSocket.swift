import SwiftUI

extension ChatViewModel {
    /// Handle WebSocket events related to chat
    func handleWebSocketEvent(_ event: WebSocketEvent?, selectedPageId: String?) {
        guard let event = event else { return }

        switch event {
        case .clarificationNeeded(let questions):
            isLoading = false
            clarificationQuestions = questions
            clarificationAnswers = []
            let response = ChatMessage(
                role: .assistant,
                content: "Before I start, I have a few questions:",
                timestamp: Date()
            )
            addMessage(response, for: selectedPageId)

        case .researchReady:
            clarificationQuestions = []
            clarificationAnswers = []
            let response = ChatMessage(
                role: .assistant,
                content: "Research complete! Review the brand report, then click 'Generate Layout' when ready.",
                timestamp: Date()
            )
            addMessage(response, for: selectedPageId)
            // Refresh project data
            Task {
                if let projectId = appState.currentProject?.id {
                    let project = try? await client.projectService.get(id: projectId)
                    appState.currentProject = project
                }
            }

        case .moodboardReady:
            clarificationQuestions = []
            clarificationAnswers = []
            let response = ChatMessage(
                role: .assistant,
                content: "Research complete! Check the main area for the brand report.",
                timestamp: Date()
            )
            addMessage(response, for: selectedPageId)
            // Refresh project data
            Task {
                if let projectId = appState.currentProject?.id {
                    let project = try? await client.projectService.get(id: projectId)
                    appState.currentProject = project
                }
            }

        case .error(let message):
            isLoading = false
            let response = ChatMessage(
                role: .assistant,
                content: "Error: \(message)",
                timestamp: Date()
            )
            addMessage(response, for: selectedPageId)

        default:
            break
        }
    }

    /// Check for pending clarification questions on the current project
    func checkForClarification() {
        guard let project = appState.currentProject,
              project.status == .clarification,
              let clarification = project.clarification else { return }

        // New multi-question format
        if let questions = clarification.questions, !questions.isEmpty {
            if clarificationQuestions.isEmpty {
                clarificationQuestions = questions
                clarificationAnswers = []
            }
        }
        // Legacy single-question fallback
        else if let question = clarification.question,
                let options = clarification.options, !options.isEmpty {
            if clarificationQuestions.isEmpty {
                clarificationQuestions = [ClarificationQuestion(question: question, options: options)]
                clarificationAnswers = []
            }
        }
    }

    /// Poll for clarification updates when Phase 1 completes before WebSocket connects.
    func pollClarificationIfNeeded(selectedPageId: String?, onProjectCreated: ((String) -> Void)?) {
        guard let project = appState.currentProject else { return }
        // Local projects don't use the API server
        guard !project.id.hasPrefix("local:") else { return }
        guard project.status != .clarification else {
            checkForClarification()
            return
        }
        guard clarificationQuestions.isEmpty else { return }

        let projectId = project.id
        Task {
            for attempt in 1...3 {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard let fetched = try? await client.projectService.get(id: projectId) else { continue }
                await MainActor.run {
                    appState.currentProject = fetched
                }
                if fetched.status == .clarification, fetched.clarification != nil {
                    await MainActor.run {
                        checkForClarification()
                    }
                    return
                }
                #if DEBUG
                print("[Chat] Clarification poll \(attempt) did not find questions yet")
                #endif
            }
        }
    }
}
