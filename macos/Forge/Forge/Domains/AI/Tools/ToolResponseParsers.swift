import Foundation

// MARK: - Response Parsers

/// Parses non-streaming OpenAI-format responses (Groq, Codex, Gemini)
enum OpenAIToolResponseParser {
    static func parse(_ data: Data) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw AIError.invalidResponse
        }

        let text = message["content"] as? String

        var toolCalls: [ToolCall] = []
        if let calls = message["tool_calls"] as? [[String: Any]] {
            for call in calls {
                guard let id = call["id"] as? String,
                      let function = call["function"] as? [String: Any],
                      let name = function["name"] as? String else { continue }
                let arguments = function["arguments"] as? String ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: arguments))
            }
        }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["prompt_tokens"] as? Int ?? 0
        let outputTokens = usage?["completion_tokens"] as? Int ?? 0

        // Preserve raw message so provider-specific fields (e.g. Gemini thought_signature) survive round-trips
        let rawMessage = try? JSONSerialization.data(withJSONObject: message)

        return ToolResponse(text: text, toolCalls: toolCalls, inputTokens: inputTokens, outputTokens: outputTokens, rawAssistantMessage: rawMessage)
    }
}

/// Parses non-streaming Anthropic-format responses (Claude)
enum AnthropicToolResponseParser {
    static func parse(_ data: Data) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }

        var text: String?
        var toolCalls: [ToolCall] = []

        for block in content {
            guard let type = block["type"] as? String else { continue }
            switch type {
            case "text":
                let t = block["text"] as? String ?? ""
                text = (text ?? "") + t
            case "tool_use":
                guard let id = block["id"] as? String,
                      let name = block["name"] as? String else { continue }
                let input = block["input"] as? [String: Any] ?? [:]
                let argsData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
                let argsString = String(data: argsData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: argsString))
            default:
                break
            }
        }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        return ToolResponse(text: text, toolCalls: toolCalls, inputTokens: inputTokens, outputTokens: outputTokens)
    }
}
