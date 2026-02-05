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

    // MARK: - Boss Coordinator

    let boss: BossCoordinator

    let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    /// Convenience accessor — API calls still go through the client's services
    var client: APIClient { appState.client }

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
        self.boss = BossCoordinator(delegate: appState)
    }
}
