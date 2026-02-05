import Foundation

/// Project status — simplified for local-only workflow
enum ProjectStatus: String, Codable {
    case active = "active"
    case archived = "archived"
}

/// A project in Forge
struct Project: Identifiable, Codable {
    let id: String
    let brief: String
    let status: ProjectStatus
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, brief, status
        case createdAt = "created_at"
    }

    /// Create a synthetic Project for local filesystem projects
    static func local(id: String, name: String) -> Project {
        Project(
            id: id,
            brief: name,
            status: .active,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
