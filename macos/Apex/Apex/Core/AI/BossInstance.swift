import Foundation
import Observation

/// Self-contained per-boss state: service + messages + workspace + vector.
@MainActor
@Observable
class BossInstance: Identifiable {
    let id: String              // "boss-0", "boss-1", etc.
    let agent: AIAgent          // .claude, .gemini, .kimi
    let vector: String?         // "luxury", "tech", nil
    let service: BossService
    var messages: [ChatMessage] = []
    var workspace: URL?
    var workspaceFiles: [LocalFileInfo] = []

    init(id: String, agent: AIAgent = .claude, vector: String? = nil) {
        self.id = id
        self.agent = agent
        self.vector = vector
        self.service = BossService(id: id, agent: agent)
    }

    /// Display name for tabs — vector name, agent name (multi-boss), or boss id
    var displayName: String {
        if let vector {
            return vector.capitalized
        }
        return agent.rawValue
    }

    /// Update the last assistant message content (for streaming)
    func updateLastMessage(content: String) {
        guard let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) else { return }
        messages[lastIndex].content = content
    }

    /// Relative project name from root (e.g. "session-20260202-1530/boss-0")
    var projectName: String? {
        guard let workspace else { return nil }
        let root = LocalWorkspaceService.shared.rootDirectory.path
        let wsPath = workspace.path
        if wsPath.hasPrefix(root + "/") {
            return String(wsPath.dropFirst(root.count + 1))
        }
        return workspace.lastPathComponent
    }

    /// Scan the workspace directory and update the file list
    func refreshWorkspaceFiles() {
        guard let name = projectName else { return }
        workspaceFiles = LocalWorkspaceService.shared.listFiles(project: name)
    }

    /// Save messages to workspace as messages.json
    func persistMessages() {
        guard let workspace else { return }
        let url = workspace.appendingPathComponent("messages.json")
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: url)
        }
    }

    /// Load messages from workspace messages.json
    func loadMessages() {
        guard let workspace else { return }
        let url = workspace.appendingPathComponent("messages.json")
        guard let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = loaded
        }
    }
}
