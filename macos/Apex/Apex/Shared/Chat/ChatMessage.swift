import Foundation

/// Role in a chat conversation
enum ChatRole {
    case user
    case assistant
}

/// Chat message model shared across all chat surfaces
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date
}
