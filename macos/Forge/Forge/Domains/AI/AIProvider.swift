import Foundation

/// Available AI providers for direct API access
enum AIProvider: String, CaseIterable, Codable {
    case groq
    case claude
    case together

    var displayName: String {
        switch self {
        case .groq: return "Llama 3.3 70B"
        case .claude: return "Opus 4.6"
        case .together: return "Together AI"
        }
    }

    var icon: String {
        switch self {
        case .groq: return "bolt.fill"
        case .claude: return "sparkles"
        case .together: return "cpu"
        }
    }

    var shortLabel: String {
        switch self {
        case .groq: return "Llama"
        case .claude: return "Opus"
        case .together: return "Together"
        }
    }

    var modelName: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .claude: return "claude-opus-4-6"
        case .together: return "meta-llama/Llama-3.3-70B-Instruct-Turbo"
        }
    }

    /// Keychain key for storing the API key
    var keychainKey: String {
        switch self {
        case .groq: return "forge.api.groq"
        case .claude: return "forge.api.claude"
        case .together: return "forge.api.together"
        }
    }

    /// Cost per million input tokens (USD)
    var inputCostPerMillion: Double {
        switch self {
        case .groq: return 0.59
        case .claude: return 5.00
        case .together: return 0.88
        }
    }

    /// Cost per million output tokens (USD)
    var outputCostPerMillion: Double {
        switch self {
        case .groq: return 0.79
        case .claude: return 25.00
        case .together: return 0.88
        }
    }
}
