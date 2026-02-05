import Foundation

extension BossService {
    // MARK: - Agent-Aware CLI Args (non-Claude only)

    func buildAgentArgs(message: String) -> [String] {
        switch agent {
        case .claude:
            // Claude uses persistent process — this should not be called
            return []

        case .gemini:
            return [message, "--sandbox", "false", "--yolo"]

        case .kimi:
            return ["--print", "--prompt", message, "--mcp-config-file", ".mcp.json"]

        case .codex:
            return ["exec", message, "--full-auto"]
        }
    }

}
