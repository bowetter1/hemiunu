import Foundation

/// Project status - matches server ProjectStatus enum
enum ProjectStatus: String, Codable {
    case brief = "brief"
    case clarification = "clarification"  // Waiting for user clarification
    case researching = "researching"      // Research in progress
    case researchDone = "research_done"   // Research complete, waiting for user to generate layouts
    case moodboard = "moodboard"          // Legacy
    case layouts = "layouts"
    case editing = "editing"
    case building = "building"          // Sandbox is building/installing
    case running = "running"            // App is running in sandbox
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

    // Daytona sandbox
    let sandboxId: String?
    let sandboxStatus: String?
    let sandboxPreviewUrl: String?

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
        case sandboxId = "sandbox_id"
        case sandboxStatus = "sandbox_status"
        case sandboxPreviewUrl = "sandbox_preview_url"
    }

    init(id: String, brief: String, status: ProjectStatus, moodboard: MoodboardContainer?, clarification: Clarification?, researchMd: String?, selectedMoodboard: Int?, selectedLayout: Int?, createdAt: String, inputTokens: Int, outputTokens: Int, costUsd: Double, errorMessage: String?, sandboxId: String?, sandboxStatus: String?, sandboxPreviewUrl: String?) {
        self.id = id
        self.brief = brief
        self.status = status
        self.moodboard = moodboard
        self.clarification = clarification
        self.researchMd = researchMd
        self.selectedMoodboard = selectedMoodboard
        self.selectedLayout = selectedLayout
        self.createdAt = createdAt
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUsd = costUsd
        self.errorMessage = errorMessage
        self.sandboxId = sandboxId
        self.sandboxStatus = sandboxStatus
        self.sandboxPreviewUrl = sandboxPreviewUrl
    }

    /// Get the list of moodboard alternatives
    var moodboards: [Moodboard] {
        moodboard?.moodboards ?? []
    }

    /// Create a synthetic Project for local filesystem projects
    static func local(id: String, name: String) -> Project {
        Project(
            id: id,
            brief: name,
            status: .done,
            moodboard: nil,
            clarification: nil,
            researchMd: nil,
            selectedMoodboard: nil,
            selectedLayout: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            inputTokens: 0,
            outputTokens: 0,
            costUsd: 0,
            errorMessage: nil,
            sandboxId: nil,
            sandboxStatus: nil,
            sandboxPreviewUrl: nil
        )
    }
}
