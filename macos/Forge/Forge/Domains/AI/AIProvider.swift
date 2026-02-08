import Foundation

/// Available AI providers for direct API access
enum AIProvider: String, CaseIterable, Codable {
    case cerebras
    case glm
    case groq
    case claude

    var displayName: String {
        switch self {
        case .cerebras: return "GPT-OSS 120B"
        case .glm: return "ZAI GLM 4.7"
        case .groq: return "Llama 3.3 70B"
        case .claude: return "Opus 4.6"
        }
    }

    var icon: String {
        switch self {
        case .cerebras: return "hare.fill"
        case .glm: return "brain.head.profile.fill"
        case .groq: return "bolt.fill"
        case .claude: return "sparkles"
        }
    }

    var shortLabel: String {
        switch self {
        case .cerebras: return "GPT-OSS"
        case .glm: return "GLM"
        case .groq: return "Llama"
        case .claude: return "Opus"
        }
    }

    var modelName: String {
        switch self {
        case .cerebras: return "gpt-oss-120b"
        case .glm: return "zai-glm-4.7"
        case .groq: return "llama-3.3-70b-versatile"
        case .claude: return "claude-opus-4-6"
        }
    }

    /// Keychain key for storing the API key
    var keychainKey: String {
        switch self {
        case .cerebras, .glm: return "forge.api.cerebras"
        case .groq: return "forge.api.groq"
        case .claude: return "forge.api.claude"
        }
    }

    /// Cost per million input tokens (USD)
    var inputCostPerMillion: Double {
        switch self {
        case .cerebras: return 0.35
        case .glm: return 2.25
        case .groq: return 0.59
        case .claude: return 5.00
        }
    }

    /// Cost per million output tokens (USD)
    var outputCostPerMillion: Double {
        switch self {
        case .cerebras: return 0.75
        case .glm: return 2.75
        case .groq: return 0.79
        case .claude: return 25.00
        }
    }
}
