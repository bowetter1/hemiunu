import SwiftUI

extension ChatViewModel {
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
        if boss.isActive {
            return boss.messages
        }
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
}
