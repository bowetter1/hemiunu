import Foundation

/// OpenAI Codex service — gpt-5.2-codex via OpenAI Responses API (/v1/responses)
/// Converts OpenAI chat format ↔ Responses API format internally so AgentLoop stays unchanged.
final class CodexService: AIService, Sendable {
    let provider: AIProvider = .codex
    private let modelName: String
    private let baseURL = URL(string: "https://api.openai.com/v1/responses")!

    init(modelOverride: String? = nil) {
        self.modelName = modelOverride ?? AIProvider.codex.modelName
    }

    // MARK: - Streaming (generate)

    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .codex)) }
        }

        // Build Responses API payload
        var input: [[String: Any]] = []
        for msg in messages {
            input.append(["role": msg.role, "content": msg.content])
        }

        let payload: [String: Any] = [
            "model": modelName,
            "instructions": systemPrompt,
            "input": input,
            "stream": true,
            "temperature": 0.7,
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.invalidResponse) }
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]

        return AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                do {
                    for try await chunk in HTTPClient.stream(url: baseURL, headers: headers, body: body) {
                        let lines = StreamingParser.splitSSELines(from: chunk, buffer: &buffer)
                        for line in lines {
                            if let content = Self.parseResponsesStreamChunk(line) {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Tool use (generateWithTools)

    func generateWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ToolResponse {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            throw AIError.noAPIKey(provider: .codex)
        }

        // Extract system message → instructions param; convert rest to Responses API input
        let (instructions, input) = convertToInput(messages, defaultInstructions: systemPrompt)
        let responsesTools = convertTools(tools)

        var payload: [String: Any] = [
            "model": modelName,
            "instructions": instructions,
            "input": input,
            "temperature": 0.7,
            "stream": false,
        ]
        if !responsesTools.isEmpty {
            payload["tools"] = responsesTools
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.invalidResponse
        }

        #if DEBUG
        if let debugJSON = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let debugStr = String(data: debugJSON, encoding: .utf8) {
            let truncated = debugStr.count > 2000 ? String(debugStr.prefix(2000)) + "\n... (truncated)" : debugStr
            print("[Codex] REQUEST to \(modelName):\n\(truncated)")
        }
        #endif

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]

        let (data, response) = try await HTTPClient.post(url: baseURL, headers: headers, body: body)

        #if DEBUG
        if let debugStr = String(data: data, encoding: .utf8) {
            let truncated = debugStr.count > 2000 ? String(debugStr.prefix(2000)) + "\n... (truncated)" : debugStr
            print("[Codex] RESPONSE (\(response.statusCode)):\n\(truncated)")
        }
        #endif

        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return try parseResponsesAPI(data)
    }

    // MARK: - Format Conversion: OpenAI Chat → Responses API

    /// Convert OpenAI chat messages to Responses API input items.
    /// Extracts the system message as `instructions`; remaining messages become input items.
    private func convertToInput(
        _ messages: [[String: Any]],
        defaultInstructions: String
    ) -> (instructions: String, input: [[String: Any]]) {
        var instructions = defaultInstructions
        var input: [[String: Any]] = []

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }

            switch role {
            case "system":
                // Extract as instructions param
                instructions = msg["content"] as? String ?? instructions

            case "user":
                input.append(["role": "user", "content": msg["content"] as? String ?? ""])

            case "assistant":
                // Check for stored _codex_output items (lossless round-trip)
                if let codexItems = msg["_codex_output"] as? [[String: Any]] {
                    input.append(contentsOf: codexItems)
                    continue
                }

                // Assistant with tool_calls → emit function_call items
                if let toolCalls = msg["tool_calls"] as? [[String: Any]] {
                    // Emit text first if present
                    if let text = msg["content"] as? String, !text.isEmpty {
                        input.append(["role": "assistant", "content": text])
                    }
                    for tc in toolCalls {
                        guard let function = tc["function"] as? [String: Any],
                              let name = function["name"] as? String else { continue }
                        let callId = tc["id"] as? String ?? "call_\(UUID().uuidString.prefix(8))"
                        let arguments = function["arguments"] as? String ?? "{}"
                        input.append([
                            "type": "function_call",
                            "call_id": callId,
                            "name": name,
                            "arguments": arguments,
                        ])
                    }
                } else {
                    // Plain text assistant message
                    input.append(["role": "assistant", "content": msg["content"] as? String ?? ""])
                }

            case "tool":
                // Tool result → function_call_output
                let callId = msg["tool_call_id"] as? String ?? ""
                let content = msg["content"] as? String ?? ""
                input.append([
                    "type": "function_call_output",
                    "call_id": callId,
                    "output": content,
                ])

            default:
                continue
            }
        }

        return (instructions, input)
    }

    /// Convert OpenAI chat tools format to Responses API tools format.
    /// Unwraps `{"type":"function","function":{...}}` → `{"type":"function","name":...,"description":...,"parameters":...}`
    private func convertTools(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            guard let function = tool["function"] as? [String: Any] else { return nil }
            var converted: [String: Any] = ["type": "function"]
            if let name = function["name"] { converted["name"] = name }
            if let desc = function["description"] { converted["description"] = desc }
            if let params = function["parameters"] { converted["parameters"] = params }
            return converted
        }
    }

    // MARK: - Response Parsing: Responses API → ToolResponse

    /// Parse Responses API response into ToolResponse.
    /// Builds rawAssistantMessage in OpenAI chat format for AgentLoop round-trip.
    private func parseResponsesAPI(_ data: Data) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }

        var textParts: [String] = []
        var toolCalls: [ToolCall] = []
        // Preserve original output items for lossless round-trip
        var codexOutputItems: [[String: Any]] = []

        for item in output {
            guard let type = item["type"] as? String else { continue }

            switch type {
            case "message":
                // {"type": "message", "content": [{"type": "output_text", "text": "..."}]}
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if block["type"] as? String == "output_text",
                           let text = block["text"] as? String {
                            textParts.append(text)
                        }
                    }
                }
                // Messages don't need round-trip storage (they're just text)

            case "function_call":
                // {"type": "function_call", "id": "fc_...", "call_id": "...", "name": "...", "arguments": "..."}
                let callId = item["call_id"] as? String ?? item["id"] as? String ?? "call_\(UUID().uuidString.prefix(8))"
                let name = item["name"] as? String ?? ""
                let arguments = item["arguments"] as? String ?? "{}"
                toolCalls.append(ToolCall(id: callId, name: name, arguments: arguments))
                // Store for lossless round-trip
                codexOutputItems.append([
                    "type": "function_call",
                    "call_id": callId,
                    "name": name,
                    "arguments": arguments,
                ])

            default:
                continue
            }
        }

        // Parse usage
        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        let text = textParts.isEmpty ? nil : textParts.joined(separator: "\n")

        // Build rawAssistantMessage in OpenAI chat format (for AgentLoop appendOpenAITurn)
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
            // Store original Responses API items for lossless round-trip
            rawMsg["_codex_output"] = codexOutputItems
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

    // MARK: - Streaming Parser

    /// Parse a Responses API SSE chunk for text content.
    /// Looks for `response.output_text.delta` events with a `delta` field.
    private static func parseResponsesStreamChunk(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data: ") else { return nil }
        let jsonStr = String(trimmed.dropFirst(6))
        guard jsonStr != "[DONE]" else { return nil }

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let eventType = json["type"] as? String

        // Text delta events
        if eventType == "response.output_text.delta",
           let delta = json["delta"] as? String {
            return delta
        }

        return nil
    }
}
