import SwiftUI

extension ChatViewModel {
    /// Get messages from the active boss instance
    var messages: [ChatMessage] {
        boss.messages
    }

    /// Get the selected page or fall back to first non-layout page
    func selectedPage(for pageId: String?) -> Page? {
        if let pageId = pageId {
            return appState.pages.first { $0.id == pageId }
        }
        return appState.pages.first { $0.layoutVariant == nil }
    }
}
