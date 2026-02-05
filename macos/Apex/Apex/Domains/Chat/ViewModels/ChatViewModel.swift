import SwiftUI

/// Unified chat view model — owns boss coordinator and routes messages to local AI agents
@MainActor
@Observable
class ChatViewModel {
    // MARK: - State

    var isLoading = false

    // MARK: - Boss Coordinator

    let boss: BossCoordinator

    let appState: AppState

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
        self.boss = BossCoordinator(delegate: appState)
    }
}
