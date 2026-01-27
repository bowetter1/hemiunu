import Foundation

/// Project status - matches server ProjectStatus enum
enum ProjectStatus: String, Codable {
    case brief = "brief"
    case clarification = "clarification"  // Waiting for user clarification
    case moodboard = "moodboard"
    case layouts = "layouts"
    case editing = "editing"
    case done = "done"
    case failed = "failed"
}

/// A single clarification question with options
struct ClarificationQuestion: Codable, Equatable {
    let question: String
    let options: [String]
}

/// Clarification data when status is .clarification
struct Clarification: Codable {
    // New multi-question format
    let questions: [ClarificationQuestion]?
    // Legacy single-question format (backward compat)
    let question: String?
    let options: [String]?
    let answer: String?
}

/// A project from apex-server
struct Project: Identifiable, Codable {
    let id: String
    let brief: String
    let status: ProjectStatus
    let moodboard: MoodboardContainer?
    let clarification: Clarification?
    let researchMd: String?
    let selectedMoodboard: Int?
    let selectedLayout: Int?
    let createdAt: String
    let inputTokens: Int
    let outputTokens: Int
    let costUsd: Double
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, brief, status, moodboard, clarification
        case researchMd = "research_md"
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
