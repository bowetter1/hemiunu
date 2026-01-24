import Foundation

/// Project status - matches server ProjectStatus enum
enum ProjectStatus: String, Codable {
    case brief = "brief"
    case moodboard = "moodboard"
    case layouts = "layouts"
    case editing = "editing"
    case done = "done"
    case failed = "failed"
}

/// Container for multiple moodboard alternatives
struct MoodboardContainer: Codable {
    let moodboards: [Moodboard]
}

/// Moodboard data from AI
struct Moodboard: Codable {
    let name: String            // "Minimalistisk", "Varm & Organisk", etc.
    let palette: [String]       // ["#hex1", "#hex2", ...]
    let fonts: MoodboardFonts
    let mood: [String]          // ["modern", "clean", ...]
    let rationale: String
}

struct MoodboardFonts: Codable {
    let heading: String
    let body: String
}

/// A project from apex-server
struct Project: Identifiable, Codable {
    let id: String
    let brief: String
    let status: ProjectStatus
    let moodboard: MoodboardContainer?
    let selectedMoodboard: Int?
    let selectedLayout: Int?
    let createdAt: String
    let inputTokens: Int
    let outputTokens: Int
    let costUsd: Double
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, brief, status, moodboard
        case selectedMoodboard = "selected_moodboard"
        case selectedLayout = "selected_layout"
        case createdAt = "created_at"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costUsd = "cost_usd"
        case errorMessage = "error_message"
    }

    /// Get the list of moodboard alternatives
    var moodboards: [Moodboard] {
        moodboard?.moodboards ?? []
    }
}

/// A page in a project
struct Page: Identifiable, Codable {
    let id: String
    let name: String
    let html: String
    let layoutVariant: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, html
        case layoutVariant = "layout_variant"
    }
}

/// Log entry from project generation
struct ProjectLog: Identifiable, Codable {
    let id: Int
    let phase: String
    let message: String
    let data: [String: AnyCodableValue]?
    let timestamp: String
}

/// Helper for decoding arbitrary JSON values
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
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
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
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
