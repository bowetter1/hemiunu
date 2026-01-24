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

// MARK: - Logs

/// Log entry from project generation
struct LogEntry: Identifiable, Codable {
    let id: Int
    let phase: String
    let message: String
    let data: [String: AnyCodable]?
    let timestamp: String
}

/// Helper for decoding arbitrary JSON values
enum AnyCodable: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
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
