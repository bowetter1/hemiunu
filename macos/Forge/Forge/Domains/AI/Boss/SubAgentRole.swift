import Foundation

/// Roles for sub-agents delegated by the Boss
enum SubAgentRole: String, Sendable, CaseIterable {
    case coder
    case researcher
    case reviewer
    case tester

    /// Which AI provider this role prefers
    var preferredProvider: AIProvider {
        switch self {
        case .coder: return .codex
        case .researcher: return .claude
        case .reviewer: return .gemini
        case .tester: return .gemini
        }
    }

    /// Optional builder name override — uses builderServiceResolver for model-specific services (e.g. Opus)
    var preferredBuilder: String? {
        switch self {
        case .researcher: return "opus"
        default: return nil
        }
    }

    /// Tool names this role is allowed to use
    var allowedTools: Set<String> {
        switch self {
        case .coder:
            return ["list_files", "read_file", "create_file", "edit_file", "delete_file", "search_images", "generate_image", "restyle_image", "download_image"]
        case .researcher:
            return ["web_search", "read_file", "create_file", "list_files"]
        case .reviewer:
            return ["list_files", "read_file"]
        case .tester:
            return ["list_files", "read_file", "take_screenshot", "review_screenshot"]
        }
    }

    /// Maximum iterations for this role's agent loop
    var maxIterations: Int {
        switch self {
        case .coder: return 50
        case .researcher: return 20
        case .reviewer: return 10
        case .tester: return 10
        }
    }
}
