import Foundation

extension GeminiBossService {
    // MARK: - Response Parsing: Gemini Native → ToolResponse

    func parseNativeResponse(_ data: Data, originalMessages: [[String: Any]]) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIError.invalidResponse
        }

        // Parse usage metadata.
        let usage = json["usageMetadata"] as? [String: Any]
        let inputTokens = usage?["promptTokenCount"] as? Int ?? 0
        let outputTokens = usage?["candidatesTokenCount"] as? Int ?? 0

        // Extract text and tool calls from parts.
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

        // Build rawAssistantMessage in OpenAI format (for AgentLoop to append).
        // Include _gemini_parts to preserve thoughtSignature for round-trip.
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
            // Preserve original Gemini parts (includes thoughtSignature).
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
