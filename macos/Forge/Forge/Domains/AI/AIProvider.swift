import Foundation

/// Available AI providers for direct API access
enum AIProvider: String, CaseIterable, Codable {
    case groq
    case claude

    var displayName: String {
        switch self {
        case .groq: return "Snabb"
        case .claude: return "Kvalitet"
        }
    }

    var icon: String {
        switch self {
        case .groq: return "bolt.fill"
        case .claude: return "sparkles"
        }
    }

    var shortLabel: String {
        switch self {
        case .groq: return "Groq"
        case .claude: return "Claude"
        }
    }

    var modelName: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .claude: return "claude-sonnet-4-5-20250929"
        }
    }

    /// Keychain key for storing the API key
    var keychainKey: String {
        switch self {
        case .groq: return "forge.api.groq"
        case .claude: return "forge.api.claude"
        }
    }
}
