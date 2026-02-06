import Foundation

/// Available AI providers for direct API access
enum AIProvider: String, CaseIterable, Codable {
    case cerebras
    case groq
    case claude

    var displayName: String {
        switch self {
        case .cerebras: return "GPT-OSS 120B"
        case .groq: return "Llama 3.3 70B"
        case .claude: return "Haiku 4.5"
        }
    }

    var icon: String {
        switch self {
        case .cerebras: return "hare.fill"
        case .groq: return "bolt.fill"
        case .claude: return "sparkles"
        }
    }

    var shortLabel: String {
        switch self {
        case .cerebras: return "GPT-OSS"
        case .groq: return "Llama"
        case .claude: return "Haiku"
        }
    }

    var modelName: String {
        switch self {
        case .cerebras: return "gpt-oss-120b"
        case .groq: return "llama-3.3-70b-versatile"
        case .claude: return "claude-haiku-4-5-20251001"
        }
    }

    /// Keychain key for storing the API key
    var keychainKey: String {
        switch self {
        case .cerebras: return "forge.api.cerebras"
        case .groq: return "forge.api.groq"
        case .claude: return "forge.api.claude"
        }
    }
}
