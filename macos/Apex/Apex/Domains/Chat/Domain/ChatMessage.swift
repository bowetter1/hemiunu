import Foundation

/// Role in a chat conversation
enum ChatRole: String, Codable {
    case user
    case assistant
}

/// Chat message model shared across all chat surfaces
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
