import Foundation

/// Roles for sub-agents delegated by the Boss
enum SubAgentRole: String, Sendable, CaseIterable {
    case coder
    case researcher
    case reviewer

    /// Which AI provider this role prefers
    var preferredProvider: AIProvider {
        switch self {
        case .coder: return .groq
        case .researcher: return .cerebras
        case .reviewer: return .cerebras
        }
    }

    /// Tool names this role is allowed to use
    var allowedTools: Set<String> {
        switch self {
        case .coder:
            return ["list_files", "read_file", "create_file", "edit_file", "delete_file"]
        case .researcher:
            return ["web_search", "read_file", "create_file", "list_files"]
        case .reviewer:
            return ["list_files", "read_file"]
        }
    }

    /// Maximum iterations for this role's agent loop
    var maxIterations: Int {
        switch self {
        case .coder: return 15
        case .researcher: return 8
        case .reviewer: return 5
        }
    }
}
