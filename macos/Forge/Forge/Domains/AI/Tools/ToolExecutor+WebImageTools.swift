import Foundation

extension ToolExecutor {
    // MARK: - Web Search

    /// Search the web via SerpAPI (Google Search).
    func executeWebSearch(query: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.serpapi"), !apiKey.isEmpty else {
            throw ToolError.missingAPIKey("SerpAPI (forge.api.serpapi in ~/Forge/.env)")
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://serpapi.com/search.json?q=\(encoded)&api_key=\(apiKey)&num=5")!

        let (data, response) = try await HTTPClient.get(url: url, headers: [:])
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return parseSerpAPIResponse(data)
    }

    /// Parse SerpAPI response: extract organic results with titles, snippets, and URLs.
    private func parseSerpAPIResponse(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "No results found."
        }

        var parts: [String] = []

        // Answer box / knowledge graph.
        if let answerBox = json["answer_box"] as? [String: Any] {
            if let answer = answerBox["answer"] as? String {
                parts.append("Answer: \(answer)")
            } else if let snippet = answerBox["snippet"] as? String {
                parts.append("Answer: \(snippet)")
            }
        }

        // Organic results.
        if let organic = json["organic_results"] as? [[String: Any]] {
            for (i, result) in organic.prefix(5).enumerated() {
                let title = result["title"] as? String ?? ""
                let snippet = result["snippet"] as? String ?? ""
                let link = result["link"] as? String ?? ""
                parts.append("\(i + 1). \(title)\n   \(snippet)\n   URL: \(link)")
            }
        }

        return parts.isEmpty ? "No results found." : parts.joined(separator: "\n\n")
    }

    // MARK: - Image Search (Pexels API)

    /// Search for stock photos via Pexels API. Returns direct image URLs.
    func executeSearchImages(query: String, count: Int) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.pexels"), !apiKey.isEmpty else {
            // Fallback: return Unsplash source URLs (no API key needed, lower quality).
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

    /// Generate an image from a text prompt via OpenAI Images API.
    func executeGenerateImage(prompt: String, filename: String) async throws -> String {
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

        // Parse response. Extract b64_json or url.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first else {
            return "Error: unexpected response format"
        }

        // Try b64_json first, then URL.
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

    /// Restyle an existing image. Download reference, send to OpenAI images/edit.
    func executeRestyleImage(referenceURL: String, stylePrompt: String, filename: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(key: "forge.api.openai"), !apiKey.isEmpty else {
            return "Error: No OpenAI API key configured (forge.api.openai). Add it in Settings to use image restyling."
        }

        // 1. Download reference image.
        guard let refURL = URL(string: referenceURL) else {
            return "Error: invalid reference URL"
        }
        let (refData, refResponse) = try await HTTPClient.get(url: refURL, headers: [:])
        guard (200...299).contains(refResponse.statusCode) else {
            return "Error: failed to download reference image (\(refResponse.statusCode))"
        }

        // 2. Build multipart form data for OpenAI images/edit.
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

    /// Download an image from a URL and save it to the project.
    func executeDownloadImage(urlString: String, filename: String) async throws -> String {
        try await downloadAndSave(urlString: urlString, filename: filename)
    }

    /// Shared helper: download from URL and save to images/.
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
}
