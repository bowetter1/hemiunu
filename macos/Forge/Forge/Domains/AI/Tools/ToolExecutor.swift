import Foundation

/// Executes tool calls against the local workspace
@MainActor
struct ToolExecutor: ToolExecuting {
    let workspace: LocalWorkspaceService
    let projectName: String

    /// Execute a tool call and return the result as a string
    func execute(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)

        switch call.name {
        case "list_files":
            return executeListFiles()

        case "read_file":
            guard let path = args["path"] as? String else {
                throw ToolError.missingParameter("path")
            }
            return try executeReadFile(path: path)

        case "create_file":
            guard let path = args["path"] as? String,
                  let content = args["content"] as? String else {
                throw ToolError.missingParameter("path and content")
            }
            return try executeCreateFile(path: path, content: content)

        case "edit_file":
            guard let path = args["path"] as? String,
                  let search = args["search"] as? String,
                  let replace = args["replace"] as? String else {
                throw ToolError.missingParameter("path, search, and replace")
            }
            return try executeEditFile(path: path, search: search, replace: replace)

        case "delete_file":
            guard let path = args["path"] as? String else {
                throw ToolError.missingParameter("path")
            }
            return try executeDeleteFile(path: path)

        case "web_search":
            guard let query = args["query"] as? String else {
                throw ToolError.missingParameter("query")
            }
            return try await executeWebSearch(query: query)

        default:
            throw ToolError.unknownTool(call.name)
        }
    }

    // MARK: - Tool Implementations

    private func executeListFiles() -> String {
        let files = workspace.listFiles(project: projectName)
        if files.isEmpty {
            return "Project is empty — no files found."
        }
        let listing = files.map { file in
            let sizeStr = file.isDirectory ? "dir" : formatSize(file.size)
            return "\(file.path) (\(sizeStr))"
        }.joined(separator: "\n")
        return listing
    }

    private func executeReadFile(path: String) throws -> String {
        try workspace.readFile(project: projectName, path: path)
    }

    private func executeCreateFile(path: String, content: String) throws -> String {
        try workspace.writeFile(project: projectName, path: path, content: content)
        return "Created \(path) (\(content.count) chars)"
    }

    private func executeEditFile(path: String, search: String, replace: String) throws -> String {
        let content = try workspace.readFile(project: projectName, path: path)
        guard content.contains(search) else {
            throw ToolError.searchStringNotFound(path: path, search: String(search.prefix(80)))
        }
        let updated = content.replacingOccurrences(of: search, with: replace)
        try workspace.writeFile(project: projectName, path: path, content: updated)
        return "Edited \(path) — replaced \(search.count) chars with \(replace.count) chars"
    }

    private func executeDeleteFile(path: String) throws -> String {
        try workspace.deleteFile(project: projectName, path: path)
        return "Deleted \(path)"
    }

    /// Search the web via Gemini 2.5 Flash + Google Search grounding
    private func executeWebSearch(query: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.gemini"), !apiKey.isEmpty else {
            throw ToolError.missingAPIKey("Gemini (forge.api.gemini in ~/Forge/.env)")
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!

        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": query]]]
            ],
            "tools": [
                ["google_search": [String: Any]()]
            ],
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.invalidResponse
        }

        let headers = [
            "x-goog-api-key": apiKey,
            "Content-Type": "application/json",
        ]

        let (data, response) = try await HTTPClient.post(url: url, headers: headers, body: body)
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return parseGeminiSearchResponse(data)
    }

    /// Parse Gemini response: extract text + grounding source URLs
    private func parseGeminiSearchResponse(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let candidate = candidates.first else {
            return "No results found."
        }

        // Extract text
        var text = ""
        if let content = candidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            for part in parts {
                if let t = part["text"] as? String {
                    text += t
                }
            }
        }

        // Extract source URLs from grounding metadata
        var sources: [String] = []
        if let metadata = candidate["groundingMetadata"] as? [String: Any],
           let chunks = metadata["groundingChunks"] as? [[String: Any]] {
            for chunk in chunks {
                if let web = chunk["web"] as? [String: Any],
                   let uri = web["uri"] as? String {
                    let title = web["title"] as? String ?? ""
                    sources.append(title.isEmpty ? uri : "\(title): \(uri)")
                }
            }
        }

        if !sources.isEmpty {
            text += "\n\nSources:\n" + sources.joined(separator: "\n")
        }

        return text.isEmpty ? "No results found." : text
    }

    // MARK: - Helpers

    private func parseArguments(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024)KB" }
        return "\(bytes / (1024 * 1024))MB"
    }
}

/// Errors during tool execution
enum ToolError: LocalizedError {
    case missingParameter(String)
    case missingAPIKey(String)
    case unknownTool(String)
    case searchStringNotFound(path: String, search: String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .missingAPIKey(let detail):
            return "Missing API key: \(detail)"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .searchStringNotFound(let path, let search):
            return "Search string not found in \(path): \"\(search)\""
        }
    }
}
