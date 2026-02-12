import Foundation

/// Gemini Boss service — uses native Gemini API with explicit context caching.
/// Unlike the OpenAI-compatible GeminiService, this service talks to Gemini's native
/// generateContent endpoint and manages a CachedContent for session continuity.
final class GeminiBossService: AIService, @unchecked Sendable {
    let provider: AIProvider = .gemini
    let modelName: String
    let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    let cacheTTL = "1800s" // 30 minutes

    /// Current cache name (e.g. "cachedContents/abc123") — set after first session.
    var cachedContentName: String?
    /// How many messages from the conversation are stored in the cache.
    var cacheMessageCount: Int = 0

    init(model: String = "gemini-3-flash-preview") {
        self.modelName = model
    }

    var apiKey: String? {
        KeychainHelper.load(key: AIProvider.gemini.keychainKey)
    }

    // MARK: - AIService (streaming — not used for Boss, minimal impl)

    func generate(messages: [AIMessage], systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .gemini)) }
    }

    // MARK: - AIService (tool use — native Gemini API)

    func generateWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ToolResponse {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey(provider: .gemini)
        }

        let url = URL(string: "\(baseURL)/models/\(modelName):generateContent?key=\(apiKey)")!

        var payload: [String: Any] = [:]

        if let cacheName = cachedContentName, cacheMessageCount > 0 {
            // Cached: tools/system/history are in the cache — only send new messages.
            let newMessages = Array(messages.dropFirst(cacheMessageCount))
            payload["cachedContent"] = cacheName
            payload["contents"] = convertMessagesToNative(newMessages)
        } else {
            // No cache: send system instruction, tools, and all messages.
            // Skip the OpenAI system message at index 0 (use systemInstruction instead).
            let conversationMessages = messages.first.flatMap({ $0["role"] as? String }) == "system"
                ? Array(messages.dropFirst())
                : messages
            let nativeTools = convertToolsToNative(tools)
            payload["systemInstruction"] = ["parts": [["text": systemPrompt]]]
            payload["tools"] = [["functionDeclarations": nativeTools]]
            payload["contents"] = convertMessagesToNative(conversationMessages)
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.invalidResponse
        }

        #if DEBUG
        if let debugJSON = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let debugStr = String(data: debugJSON, encoding: .utf8) {
            let truncated = debugStr.count > 2000 ? String(debugStr.prefix(2000)) + "\n... (truncated)" : debugStr
            print("[GeminiBoss] REQUEST to \(modelName):\n\(truncated)")
        }
        #endif

        let headers = ["Content-Type": "application/json"]
        let (data, response) = try await HTTPClient.post(url: url, headers: headers, body: body)

        #if DEBUG
        if let debugStr = String(data: data, encoding: .utf8) {
            let truncated = debugStr.count > 2000 ? String(debugStr.prefix(2000)) + "\n... (truncated)" : debugStr
            print("[GeminiBoss] RESPONSE (\(response.statusCode)):\n\(truncated)")
        }
        #endif

        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return try parseNativeResponse(data, originalMessages: messages)
    }
}
