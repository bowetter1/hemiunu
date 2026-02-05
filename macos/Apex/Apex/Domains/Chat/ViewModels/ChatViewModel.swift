import SwiftUI

/// Unified chat view model — owns all chat state and logic for all 3 chat surfaces
@MainActor
@Observable
class ChatViewModel {
    // MARK: - State

    /// Messages stored per page (pageId -> messages)
    var messagesByPage: [String: [ChatMessage]] = [:]
    /// Messages for when no page is selected (new project flow)
    var globalMessages: [ChatMessage] = []
    var isLoading = false

    /// Multi-question clarification state (canonical model from ChatTabContent)
    var clarificationQuestions: [ClarificationQuestion] = []
    var clarificationAnswers: [String] = []

    // MARK: - Boss Coordinator

    let boss: BossCoordinator

    let appState: AppState

    /// Convenience accessor — API calls still go through the client's services
    var client: APIClient { appState.client }

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
        self.boss = BossCoordinator(delegate: appState)
    }
}
