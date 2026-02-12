import Foundation

extension GeminiBossService {
    // MARK: - Cache Management

    /// Create or update the cache with the full conversation history.
    func updateCache(systemPrompt: String, messages: [[String: Any]]) async {
        guard let apiKey, !apiKey.isEmpty else { return }

        // Delete old cache first.
        if let oldName = cachedContentName {
            await deleteCache(name: oldName)
        }

        // Skip system message at index 0 — goes into systemInstruction.
        let conversationMessages = messages.first.flatMap({ $0["role"] as? String }) == "system"
            ? Array(messages.dropFirst())
            : messages

        // Need at least some messages to cache.
        guard !conversationMessages.isEmpty else { return }

        let nativeTools = convertToolsToNative(ForgeTools.bossOpenAIFormat())
        let payload: [String: Any] = [
            "model": "models/\(modelName)",
            "displayName": "forge-boss",
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "tools": [["functionDeclarations": nativeTools]],
            "contents": convertMessagesToNative(conversationMessages),
            "ttl": cacheTTL,
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        let url = URL(string: "\(baseURL)/cachedContents?key=\(apiKey)")!
        let headers = ["Content-Type": "application/json"]

        do {
            let (data, response) = try await HTTPClient.post(url: url, headers: headers, body: body)
            guard (200...299).contains(response.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String
            else {
                #if DEBUG
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("[GeminiBoss] Cache creation failed: \(msg)")
                #endif
                return
            }
            cachedContentName = name
            cacheMessageCount = messages.count // includes system message
            #if DEBUG
            print("[GeminiBoss] Cache created: \(name) (\(messages.count) messages)")
            #endif
        } catch {
            #if DEBUG
            print("[GeminiBoss] Cache creation error: \(error)")
            #endif
        }
    }

    /// Delete a cache by name.
    private func deleteCache(name: String) async {
        guard let apiKey else { return }
        let url = URL(string: "\(baseURL)/\(name)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
        #if DEBUG
        print("[GeminiBoss] Deleted cache: \(name)")
        #endif
    }

    /// Clear cache state (e.g. on project switch).
    func clearCache() async {
        if let name = cachedContentName {
            await deleteCache(name: name)
        }
        cachedContentName = nil
        cacheMessageCount = 0
    }
}
