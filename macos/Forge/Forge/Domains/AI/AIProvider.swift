import Foundation

/// Available AI providers for direct API access
enum AIProvider: String, CaseIterable, Codable {
    case groq
    case claude
    case gemini
    case kimi

    var displayName: String {
        switch self {
        case .groq: return "Llama 3.3 70B"
        case .claude: return "Claude Haiku 4.5"
        case .gemini: return "Gemini 2.5 Flash"
        case .kimi: return "Kimi K2.5"
        }
    }

    var icon: String {
        switch self {
        case .groq: return "bolt.fill"
        case .claude: return "sparkles"
        case .gemini: return "globe"
        case .kimi: return "moon.stars"
        }
    }

    var shortLabel: String {
        switch self {
        case .groq: return "Llama"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .kimi: return "Kimi"
        }
    }

    var modelName: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .claude: return "claude-haiku-4-5-20251001"
        case .gemini: return "gemini-2.5-flash"
        case .kimi: return "kimi-k2-0711"
        }
    }

    /// Keychain key for storing the API key
    var keychainKey: String {
        switch self {
        case .groq: return "forge.api.groq"
        case .claude: return "forge.api.claude"
        case .gemini: return "forge.api.gemini"
        case .kimi: return "forge.api.kimi"
        }
    }

    /// Cost per million input tokens (USD)
    var inputCostPerMillion: Double {
        switch self {
        case .groq: return 0.59
        case .claude: return 0.80
        case .gemini: return 0.15
        case .kimi: return 0.60
        }
    }

    /// Cost per million output tokens (USD)
    var outputCostPerMillion: Double {
        switch self {
        case .groq: return 0.79
        case .claude: return 4.00
        case .gemini: return 0.60
        case .kimi: return 2.50
        }
    }
}
