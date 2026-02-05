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

    /// Save messages to workspace as messages.json (atomic write-to-temp-then-rename)
    func persistMessages() {
        guard let workspace else { return }
        let url = workspace.appendingPathComponent("messages.json")
        let tmpURL = workspace.appendingPathComponent("messages.json.tmp")
        guard let data = try? JSONEncoder().encode(messages) else { return }

        do {
            try data.write(to: tmpURL)
            // Atomic swap — if the destination already exists, replaceItemAt handles it
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: url)
            }
        } catch {
            print("[Workspace] FAILED to persist messages.json: \(error.localizedDescription)")
            // Clean up tmp file if swap failed
            try? FileManager.default.removeItem(at: tmpURL)
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
