import Foundation

/// Persists chat history as JSON in the project workspace
struct ChatHistoryService {

    func save(_ messages: [ChatMessage], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func load(from url: URL) -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    @MainActor func historyURL(workspace: LocalWorkspaceService, projectId: String?,
                               projectNameResolver: (String) -> String?) -> URL? {
        guard let projectId = projectId,
              let projectName = projectNameResolver(projectId) else { return nil }
        return workspace.projectPath(projectName).appendingPathComponent("chat-history.json")
    }
}
