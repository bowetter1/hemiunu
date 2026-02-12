import Foundation

/// Roles for sub-agents delegated by the Boss
enum SubAgentRole: String, Sendable, CaseIterable {
    case coder
    case reviewer
    case tester
    case deployer

    /// Which AI provider this role prefers
    var preferredProvider: AIProvider {
        switch self {
        case .coder: return .codex
        case .reviewer: return .gemini
        case .tester: return .gemini
        case .deployer: return .claude
        }
    }

    /// Optional builder name override — uses builderServiceResolver for model-specific services (e.g. Opus)
    var preferredBuilder: String? {
        switch self {
        case .deployer: return "opus"
        default: return nil
        }
    }

    /// Tool names this role is allowed to use
    var allowedTools: Set<String> {
        switch self {
        case .coder:
            return ["list_files", "read_file", "create_file", "edit_file", "delete_file", "search_images", "generate_image", "restyle_image", "download_image", "run_command"]
        case .reviewer:
            return ["list_files", "read_file"]
        case .tester:
            return ["list_files", "read_file", "take_screenshot", "review_screenshot"]
        case .deployer:
            return ["list_files", "read_file", "sandbox_create", "sandbox_upload", "sandbox_exec", "sandbox_preview_url", "sandbox_stop", "run_command"]
        }
    }

    /// Maximum iterations for this role's agent loop
    var maxIterations: Int {
        switch self {
        case .coder: return 50
        case .reviewer: return 10
        case .tester: return 10
        case .deployer: return 30
        }
    }
}
