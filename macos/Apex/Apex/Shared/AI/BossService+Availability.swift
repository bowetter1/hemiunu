import Foundation

extension BossService {
    // MARK: - Availability

    static func cliPath(for agent: AIAgent) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch agent {
        case .claude: return "\(home)/.local/bin/claude"
        case .gemini: return "/opt/homebrew/bin/gemini"
        case .kimi:   return "\(home)/.local/bin/kimi"
        case .codex:  return "/opt/homebrew/bin/codex"
        }
    }

    static func isAvailable(agent: AIAgent) -> Bool {
        FileManager.default.fileExists(atPath: cliPath(for: agent))
    }

    /// Legacy convenience — checks Claude availability
    static var isAvailable: Bool {
        isAvailable(agent: .claude)
    }

}
