import Foundation

// MARK: - Errors

enum BossError: LocalizedError {
    case notInstalled(AIAgent)
    case launchFailed(String)
    case exitCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let agent):
            return "\(agent.rawValue) CLI is not installed"
        case .launchFailed(let msg):
            return "Failed to launch boss: \(msg)"
        case .exitCode(let code, let msg):
            return "Boss exited with code \(code): \(msg)"
        }
    }
}
