import Foundation

/// Gemini Boss service — uses native Gemini API with explicit context caching.
/// Unlike the OpenAI-compatible GeminiService, this service talks to Gemini's native
/// generateContent endpoint and manages a CachedContent for session continuity.
final class GeminiBossService: AIService, @unchecked Sendable {
    let provider: AIProvider = .gemini
    private let modelName: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let cacheTTL = "1800s" // 30 minutes

    /// Current cache name (e.g. "cachedContents/abc123") — set after first session
    var cachedContentName: String?
    /// How many messages from the conversation are stored in the cache
    var cacheMessageCount: Int = 0

    init(model: String = "gemini-3-flash-preview") {
        self.modelName = model
    }

    private var apiKey: String? {
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
            // Cached: tools/system/history are in the cache — only send new messages
            let newMessages = Array(messages.dropFirst(cacheMessageCount))
            payload["cachedContent"] = cacheName
            payload["contents"] = convertMessagesToNative(newMessages)
        } else {
            // No cache: send system instruction, tools, and all messages
            // Skip the OpenAI system message at index 0 (use systemInstruction instead)
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

    // MARK: - Cache Management

    /// Create or update the cache with the full conversation history
    func updateCache(systemPrompt: String, messages: [[String: Any]]) async {
        guard let apiKey, !apiKey.isEmpty else { return }

        // Delete old cache first
        if let oldName = cachedContentName {
            await deleteCache(name: oldName)
        }

        // Skip system message at index 0 — goes into systemInstruction
        let conversationMessages = messages.first.flatMap({ $0["role"] as? String }) == "system"
            ? Array(messages.dropFirst())
            : messages

        // Need at least some messages to cache
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

    /// Delete a cache by name
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

    /// Clear cache state (e.g. on project switch)
    func clearCache() async {
        if let name = cachedContentName {
            await deleteCache(name: name)
        }
        cachedContentName = nil
        cacheMessageCount = 0
    }

    // MARK: - Format Conversion: OpenAI → Gemini Native

    /// Convert OpenAI-format messages to Gemini native contents
    private func convertMessagesToNative(_ messages: [[String: Any]]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        // Track tool call IDs → names for functionResponse conversion
        var toolCallIdToName: [String: String] = [:]

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }

            switch role {
            case "system":
                // System messages are handled via systemInstruction, skip
                continue

            case "user":
                result.append([
                    "role": "user",
                    "parts": [["text": msg["content"] as? String ?? ""]],
                ])

            case "assistant":
                // Use original Gemini parts if available (preserves thoughtSignature)
                if let geminiParts = msg["_gemini_parts"] as? [[String: Any]] {
                    // Track tool call IDs → names from OpenAI format
                    if let toolCalls = msg["tool_calls"] as? [[String: Any]] {
                        for tc in toolCalls {
                            if let id = tc["id"] as? String,
                               let function = tc["function"] as? [String: Any],
                               let name = function["name"] as? String {
                                toolCallIdToName[id] = name
                            }
                        }
                    }
                    result.append(["role": "model", "parts": geminiParts])
                    continue
                }

                var parts: [[String: Any]] = []

                // Text content
                if let text = msg["content"] as? String, !text.isEmpty {
                    parts.append(["text": text])
                }

                // Tool calls → functionCall
                if let toolCalls = msg["tool_calls"] as? [[String: Any]] {
                    for tc in toolCalls {
                        guard let function = tc["function"] as? [String: Any],
                              let name = function["name"] as? String,
                              let argsString = function["arguments"] as? String,
                              let argsData = argsString.data(using: .utf8),
                              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
                        else { continue }

                        // Track ID → name mapping
                        if let id = tc["id"] as? String {
                            toolCallIdToName[id] = name
                        }

                        parts.append(["functionCall": ["name": name, "args": args]])
                    }
                }

                if !parts.isEmpty {
                    result.append(["role": "model", "parts": parts])
                }

            case "tool":
                // Tool result → functionResponse
                let toolCallId = msg["tool_call_id"] as? String ?? ""
                let name = toolCallIdToName[toolCallId] ?? "unknown"
                let content = msg["content"] as? String ?? ""

                result.append([
                    "role": "user",
                    "parts": [
                        ["functionResponse": [
                            "name": name,
                            "response": ["result": content],
                        ] as [String: Any]],
                    ],
                ])

            default:
                continue
            }
        }

        // Gemini requires alternating user/model roles — merge consecutive same-role messages
        return mergeConsecutiveRoles(result)
    }

    /// Merge consecutive messages with the same role (Gemini requires strict alternation)
    private func mergeConsecutiveRoles(_ messages: [[String: Any]]) -> [[String: Any]] {
        guard !messages.isEmpty else { return [] }
        var merged: [[String: Any]] = [messages[0]]

        for i in 1..<messages.count {
            let currentRole = messages[i]["role"] as? String ?? ""
            let lastRole = merged.last?["role"] as? String ?? ""

            if currentRole == lastRole {
                // Merge parts into previous message
                var lastMsg = merged.removeLast()
                var lastParts = lastMsg["parts"] as? [[String: Any]] ?? []
                let newParts = messages[i]["parts"] as? [[String: Any]] ?? []
                lastParts.append(contentsOf: newParts)
                lastMsg["parts"] = lastParts
                merged.append(lastMsg)
            } else {
                merged.append(messages[i])
            }
        }
        return merged
    }

    /// Convert OpenAI-format tools to Gemini native functionDeclarations
    private func convertToolsToNative(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            guard let function = tool["function"] as? [String: Any] else { return nil }
            var declaration: [String: Any] = [:]
            if let name = function["name"] { declaration["name"] = name }
            if let desc = function["description"] { declaration["description"] = desc }
            if let params = function["parameters"] { declaration["parameters"] = params }
            return declaration
        }
    }

    // MARK: - Response Parsing: Gemini Native → ToolResponse

    private func parseNativeResponse(_ data: Data, originalMessages: [[String: Any]]) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIError.invalidResponse
        }

        // Parse usage metadata
        let usage = json["usageMetadata"] as? [String: Any]
        let inputTokens = usage?["promptTokenCount"] as? Int ?? 0
        let outputTokens = usage?["candidatesTokenCount"] as? Int ?? 0

        // Extract text and tool calls from parts
        var textParts: [String] = []
        var toolCalls: [ToolCall] = []

        for part in parts {
            if let text = part["text"] as? String {
                textParts.append(text)
            }
            if let fc = part["functionCall"] as? [String: Any],
               let name = fc["name"] as? String {
                let args = fc["args"] as? [String: Any] ?? [:]
                let argsData = (try? JSONSerialization.data(withJSONObject: args)) ?? Data()
                let argsString = String(data: argsData, encoding: .utf8) ?? "{}"
                let id = "call_\(UUID().uuidString.prefix(8))"
                toolCalls.append(ToolCall(id: id, name: name, arguments: argsString))
            }
        }

        let text = textParts.isEmpty ? nil : textParts.joined(separator: "\n")

        // Build rawAssistantMessage in OpenAI format (for AgentLoop to append)
        // Include _gemini_parts to preserve thoughtSignature for round-trip
        var rawMsg: [String: Any] = ["role": "assistant"]
        if let text { rawMsg["content"] = text }
        if !toolCalls.isEmpty {
            rawMsg["tool_calls"] = toolCalls.map { call in
                [
                    "id": call.id,
                    "type": "function",
                    "function": [
                        "name": call.name,
                        "arguments": call.arguments,
                    ] as [String: Any],
                ] as [String: Any]
            }
            // Preserve original Gemini parts (includes thoughtSignature)
            rawMsg["_gemini_parts"] = parts
        }
        let rawData = try? JSONSerialization.data(withJSONObject: rawMsg)

        return ToolResponse(
            text: text,
            toolCalls: toolCalls,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            rawAssistantMessage: rawData
        )
    }
}
