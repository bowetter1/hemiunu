import Foundation

// MARK: - AI Message Types

/// Role in a conversation
enum AIRole: String, Codable {
    case user
    case assistant
    case system
}

/// A message in an AI conversation
struct AIMessage: Identifiable, Codable {
    let id: UUID
    let role: AIRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: AIRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// A question/request sent to the AI
struct AIQuestion: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Streaming

/// Represents a chunk of streamed AI response
struct AIStreamChunk {
    let text: String
    let isComplete: Bool
}

// MARK: - Errors

enum AIError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI"
        case .rateLimited:
            return "Rate limited, please wait"
        case .unauthorized:
            return "Unauthorized"
        }
    }
}
