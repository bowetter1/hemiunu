import SwiftUI
import Combine

/// Unified chat view model — owns all chat state and logic for all 3 chat surfaces
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - State

    /// Messages stored per page (pageId -> messages)
    @Published var messagesByPage: [String: [ChatMessage]] = [:]
    /// Messages for when no page is selected (new project flow)
    @Published var globalMessages: [ChatMessage] = []
    @Published var isLoading = false

    /// Multi-question clarification state (canonical model from ChatTabContent)
    @Published var clarificationQuestions: [ClarificationQuestion] = []
    @Published var clarificationAnswers: [String] = []

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    /// Convenience accessor — API calls still go through the client's services
    private var client: APIClient { appState.client }

    // MARK: - Computed

    /// The current question index (how many have been answered)
    var currentQuestionIndex: Int {
        clarificationAnswers.count
    }

    /// The current question to show, if any
    var currentQuestion: ClarificationQuestion? {
        guard currentQuestionIndex < clarificationQuestions.count else { return nil }
        return clarificationQuestions[currentQuestionIndex]
    }

    /// Get messages for a specific page (or global if nil)
    func messages(for pageId: String?) -> [ChatMessage] {
        if let pageId = pageId {
            return messagesByPage[pageId] ?? []
        }
        return globalMessages
    }

    /// Get the selected page or fall back to first non-layout page
    func selectedPage(for pageId: String?) -> Page? {
        if let pageId = pageId {
            return appState.pages.first { $0.id == pageId }
        }
        return appState.pages.first { $0.layoutVariant == nil }
    }

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

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
