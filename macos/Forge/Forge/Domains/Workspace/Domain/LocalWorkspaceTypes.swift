import Foundation

// MARK: - Data Types

struct ShellResult {
    let exitCode: Int
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

enum WorkspaceError: LocalizedError {
    case invalidURL
    case cloneFailed(String)
    case installFailed(String)
    case buildFailed(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .cloneFailed(let output): return "Clone failed: \(output)"
        case .installFailed(let output): return "Install failed: \(output)"
        case .buildFailed(let output): return "Build failed: \(output)"
        case .processLaunchFailed(let msg): return "Process launch failed: \(msg)"
        }
    }
}
