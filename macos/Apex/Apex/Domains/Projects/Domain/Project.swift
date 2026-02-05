import Foundation

/// Project status - matches server ProjectStatus enum
enum ProjectStatus: String, Codable {
    case brief = "brief"
    case clarification = "clarification"
    case researching = "researching"
    case researchDone = "research_done"
    case moodboard = "moodboard"
    case layouts = "layouts"
    case editing = "editing"
    case building = "building"
    case running = "running"
    case done = "done"
    case failed = "failed"
}

/// A project from apex-server
struct Project: Identifiable, Codable {
    let id: String
    let brief: String
    let status: ProjectStatus
    let moodboard: MoodboardContainer?
    let researchMd: String?
    let createdAt: String
    let errorMessage: String?
    let sandboxId: String?
    let sandboxPreviewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, brief, status, moodboard
        case researchMd = "research_md"
        case createdAt = "created_at"
        case errorMessage = "error_message"
        case sandboxId = "sandbox_id"
        case sandboxPreviewUrl = "sandbox_preview_url"
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
            researchMd: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            errorMessage: nil,
            sandboxId: nil,
            sandboxPreviewUrl: nil
        )
    }
}
