import Foundation

/// A log entry from a sprint
struct LogEntry: Identifiable, Codable {
    let id: Int
    var timestamp: String  // ISO8601 string from server
    var logType: LogType
    var worker: String?
    var message: String
    var data: String?  // Optional JSON string

    enum CodingKeys: String, CodingKey {
        case id, timestamp, worker, message, data
        case logType = "log_type"
    }
}

enum LogType: String, Codable {
    // Server log types
    case info
    case phase
    case workerStart = "worker_start"
    case workerDone = "worker_done"
    case toolCall = "tool_call"
    case toolResult = "tool_result"
    case thinking
    case parallelStart = "parallel_start"
    case parallelDone = "parallel_done"
    case error
    case success
}
