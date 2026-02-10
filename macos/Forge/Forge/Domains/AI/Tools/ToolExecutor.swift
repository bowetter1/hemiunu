import Foundation

/// Executes tool calls against the local workspace
@MainActor
struct ToolExecutor: ToolExecuting {
    let workspace: LocalWorkspaceService
    let projectName: String
    var onFileWrite: (() -> Void)?

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

        case "search_images":
            guard let query = args["query"] as? String else {
                throw ToolError.missingParameter("query")
            }
            let count = args["count"] as? Int ?? 3
            return try await executeSearchImages(query: query, count: min(max(count, 1), 5))

        case "generate_image":
            guard let prompt = args["prompt"] as? String else {
                throw ToolError.missingParameter("prompt")
            }
            let filename = args["filename"] as? String ?? "generated-\(UUID().uuidString.prefix(6)).png"
            return try await executeGenerateImage(prompt: prompt, filename: filename)

        case "restyle_image":
            guard let referenceURL = args["reference_url"] as? String,
                  let stylePrompt = args["style_prompt"] as? String else {
                throw ToolError.missingParameter("reference_url and style_prompt")
            }
            let filename = args["filename"] as? String ?? "restyled-\(UUID().uuidString.prefix(6)).png"
            return try await executeRestyleImage(referenceURL: referenceURL, stylePrompt: stylePrompt, filename: filename)

        case "download_image":
            guard let urlString = args["url"] as? String,
                  let filename = args["filename"] as? String else {
                throw ToolError.missingParameter("url and filename")
            }
            return try await executeDownloadImage(urlString: urlString, filename: filename)

        case "take_screenshot":
            let width = args["width"] as? Int ?? 1280
            let height = args["height"] as? Int ?? 800
            return executeTakeScreenshot(width: width, height: height)

        case "review_screenshot":
            let focus = args["focus"] as? String ?? "overall"
            return executeReviewScreenshot(focus: focus)

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
        onFileWrite?()
        return "Created \(path) (\(content.count) chars)"
    }

    private func executeEditFile(path: String, search: String, replace: String) throws -> String {
        let content = try workspace.readFile(project: projectName, path: path)
        guard content.contains(search) else {
            throw ToolError.searchStringNotFound(path: path, search: String(search.prefix(80)))
        }
        let updated = content.replacingOccurrences(of: search, with: replace)
        try workspace.writeFile(project: projectName, path: path, content: updated)
        onFileWrite?()
        let snippet = contextSnippet(content: updated, around: replace)
        return "Edited \(path) — replaced \(search.count) chars with \(replace.count) chars\n\n\(snippet)"
    }

    /// Extract a few lines around the replaced text so the LLM can verify without a full read_file
    private func contextSnippet(content: String, around target: String, contextLines: Int = 2) -> String {
        guard let range = content.range(of: target) else { return "" }
        let lines = content.components(separatedBy: "\n")
        let prefix = content[content.startIndex..<range.lowerBound]
        let targetLine = prefix.components(separatedBy: "\n").count - 1
        let start = max(0, targetLine - contextLines)
        let end = min(lines.count - 1, targetLine + target.components(separatedBy: "\n").count - 1 + contextLines)
        let slice = lines[start...end].enumerated().map { (i, line) in
            let lineNum = start + i + 1
            return String(format: "%4d│ %@", lineNum, String(line.prefix(120)))
        }
        return slice.joined(separator: "\n")
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

    // MARK: - Image Search (Pexels API)

    /// Search for stock photos via Pexels API — returns direct image URLs
    private func executeSearchImages(query: String, count: Int) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.pexels"), !apiKey.isEmpty else {
            // Fallback: return Unsplash source URLs (no API key needed, lower quality)
            return (1...count).map { i in
                "Image \(i): https://images.unsplash.com/photo-\(query.replacingOccurrences(of: " ", with: "-"))?w=1200&h=800&fit=crop"
            }.joined(separator: "\n") + "\n\nNote: These are Unsplash URLs. For better results, add a Pexels API key (forge.api.pexels)."
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.pexels.com/v1/search?query=\(encoded)&per_page=\(count)&orientation=landscape")!

        let headers = [
            "Authorization": apiKey,
        ]

        let (data, response) = try await HTTPClient.get(url: url, headers: headers)
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "Pexels search failed (\(response.statusCode)): \(msg)"
        }

        return parsePexelsResponse(data)
    }

    private func parsePexelsResponse(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let photos = json["photos"] as? [[String: Any]] else {
            return "No images found."
        }

        if photos.isEmpty { return "No images found for this query." }

        let results = photos.enumerated().map { (i, photo) in
            let photographer = photo["photographer"] as? String ?? "Unknown"
            let alt = photo["alt"] as? String ?? ""
            let src = photo["src"] as? [String: Any]
            let large2x = src?["large2x"] as? String ?? ""
            let large = src?["large"] as? String ?? large2x
            let original = src?["original"] as? String ?? large

            return """
            Image \(i + 1):
              URL (large): \(large)
              URL (original): \(original)
              Alt: \(alt)
              Photographer: \(photographer) (Pexels)
            """
        }

        return results.joined(separator: "\n\n")
    }

    // MARK: - AI Image Generation (OpenAI GPT-Image-1)

    /// Generate an image from a text prompt via OpenAI Images API
    private func executeGenerateImage(prompt: String, filename: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.openai"), !apiKey.isEmpty else {
            return "Error: No OpenAI API key configured (forge.api.openai). Add it in Settings to use AI image generation."
        }

        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        let payload: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "n": 1,
            "size": "1536x1024",
            "quality": "medium",
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return "Error: failed to encode request"
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]

        let (data, response) = try await HTTPClient.post(url: url, headers: headers, body: body)
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "Error generating image (\(response.statusCode)): \(String(msg.prefix(200)))"
        }

        // Parse response — extract b64_json or url
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first else {
            return "Error: unexpected response format"
        }

        // Try b64_json first, then URL
        if let b64 = first["b64_json"] as? String, let imageData = Data(base64Encoded: b64) {
            let path = "images/\(filename)"
            try workspace.writeBinary(project: projectName, path: path, data: imageData)
            onFileWrite?()
            return "Generated image saved to \(path) — use src=\"\(path)\" in your HTML"
        } else if let imageURL = first["url"] as? String {
            return try await downloadAndSave(urlString: imageURL, filename: filename)
        }

        return "Error: no image data in response"
    }

    /// Restyle an existing image — download reference, send to OpenAI images/edit
    private func executeRestyleImage(referenceURL: String, stylePrompt: String, filename: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.openai"), !apiKey.isEmpty else {
            return "Error: No OpenAI API key configured (forge.api.openai). Add it in Settings to use image restyling."
        }

        // 1. Download reference image
        guard let refURL = URL(string: referenceURL) else {
            return "Error: invalid reference URL"
        }
        let (refData, refResponse) = try await HTTPClient.get(url: refURL, headers: [:])
        guard (200...299).contains(refResponse.statusCode) else {
            return "Error: failed to download reference image (\(refResponse.statusCode))"
        }

        // 2. Build multipart form data for OpenAI images/edit
        let boundary = "Forge-\(UUID().uuidString)"
        var bodyData = Data()

        // image field
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"reference.png\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        bodyData.append(refData)
        bodyData.append("\r\n".data(using: .utf8)!)

        // prompt field
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append(stylePrompt.data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)

        // model field
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("gpt-image-1".data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)

        // size field
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("1536x1024".data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)

        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = URL(string: "https://api.openai.com/v1/images/edits")!
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "multipart/form-data; boundary=\(boundary)",
        ]

        let (data, response) = try await HTTPClient.post(url: url, headers: headers, body: bodyData)
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "Error restyling image (\(response.statusCode)): \(String(msg.prefix(200)))"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first else {
            return "Error: unexpected response format"
        }

        if let b64 = first["b64_json"] as? String, let imageData = Data(base64Encoded: b64) {
            let path = "images/\(filename)"
            try workspace.writeBinary(project: projectName, path: path, data: imageData)
            onFileWrite?()
            return "Restyled image saved to \(path) — use src=\"\(path)\" in your HTML"
        } else if let imageURL = first["url"] as? String {
            return try await downloadAndSave(urlString: imageURL, filename: filename)
        }

        return "Error: no image data in response"
    }

    // MARK: - Download Image

    /// Download an image from a URL and save it to the project
    private func executeDownloadImage(urlString: String, filename: String) async throws -> String {
        return try await downloadAndSave(urlString: urlString, filename: filename)
    }

    /// Shared helper: download from URL and save to images/
    private func downloadAndSave(urlString: String, filename: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            return "Error: invalid URL"
        }

        let (data, response) = try await HTTPClient.get(url: url, headers: [:])
        guard (200...299).contains(response.statusCode) else {
            return "Error: download failed (\(response.statusCode))"
        }

        let path = "images/\(filename)"
        try workspace.writeBinary(project: projectName, path: path, data: data)
        onFileWrite?()
        return "Downloaded and saved to \(path) (\(data.count / 1024)KB) — use src=\"\(path)\" in your HTML"
    }

    // MARK: - Screenshot Tools (not yet implemented)

    private func executeTakeScreenshot(width: Int, height: Int) -> String {
        "Screenshot not available — use read_file to inspect the HTML directly."
    }

    private func executeReviewScreenshot(focus: String) -> String {
        "Visual review not available — use read_file to review the HTML/CSS code directly."
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
