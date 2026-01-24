import Foundation

/// Represents a sprint from apex-server
struct Sprint: Identifiable, Codable {
    let id: String
    var task: String
    var status: SprintStatus
    var projectDir: String?
    var team: String?
    var githubRepo: String?
    var createdAt: String  // ISO8601 string from server
    var startedAt: String?
    var completedAt: String?
    var errorMessage: String?
    var inputTokens: Int
    var outputTokens: Int
    var costUsd: Double

    enum CodingKeys: String, CodingKey {
        case id, task, status, team
        case projectDir = "project_dir"
        case githubRepo = "github_repo"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case errorMessage = "error_message"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costUsd = "cost_usd"
    }
}

enum SprintStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

/// Request to create a new sprint
struct CreateSprintRequest: Codable {
    let task: String
    let team: String

    init(task: String, team: String = "a-team") {
        self.task = task
        self.team = team
    }
}

/// AI Question from the server
struct AIQuestion: Identifiable, Codable {
    let id: Int
    let question: String
    let options: [String]?
    let status: String
    let createdAt: String
    var answer: String?
    var answeredAt: String?

    enum CodingKeys: String, CodingKey {
        case id, question, options, status, answer
        case createdAt = "created_at"
        case answeredAt = "answered_at"
    }
}
