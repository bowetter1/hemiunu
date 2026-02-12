import Foundation

extension GeminiBossService {
    // MARK: - Format Conversion: OpenAI → Gemini Native

    /// Convert OpenAI-format messages to Gemini native contents.
    func convertMessagesToNative(_ messages: [[String: Any]]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        // Track tool call IDs → names for functionResponse conversion.
        var toolCallIdToName: [String: String] = [:]

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }

            switch role {
            case "system":
                // System messages are handled via systemInstruction, skip.
                continue

            case "user":
                result.append([
                    "role": "user",
                    "parts": [["text": msg["content"] as? String ?? ""]],
                ])

            case "assistant":
                // Use original Gemini parts if available (preserves thoughtSignature).
                if let geminiParts = msg["_gemini_parts"] as? [[String: Any]] {
                    // Track tool call IDs → names from OpenAI format.
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

                // Text content.
                if let text = msg["content"] as? String, !text.isEmpty {
                    parts.append(["text": text])
                }

                // Tool calls → functionCall.
                if let toolCalls = msg["tool_calls"] as? [[String: Any]] {
                    for tc in toolCalls {
                        guard let function = tc["function"] as? [String: Any],
                              let name = function["name"] as? String,
                              let argsString = function["arguments"] as? String,
                              let argsData = argsString.data(using: .utf8),
                              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
                        else { continue }

                        // Track ID → name mapping.
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
                // Tool result → functionResponse.
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

        // Gemini requires alternating user/model roles — merge consecutive same-role messages.
        return mergeConsecutiveRoles(result)
    }

    /// Merge consecutive messages with the same role (Gemini requires strict alternation).
    private func mergeConsecutiveRoles(_ messages: [[String: Any]]) -> [[String: Any]] {
        guard !messages.isEmpty else { return [] }
        var merged: [[String: Any]] = [messages[0]]

        for i in 1..<messages.count {
            let currentRole = messages[i]["role"] as? String ?? ""
            let lastRole = merged.last?["role"] as? String ?? ""

            if currentRole == lastRole {
                // Merge parts into previous message.
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

    /// Convert OpenAI-format tools to Gemini native functionDeclarations.
    func convertToolsToNative(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            guard let function = tool["function"] as? [String: Any] else { return nil }
            var declaration: [String: Any] = [:]
            if let name = function["name"] { declaration["name"] = name }
            if let desc = function["description"] { declaration["description"] = desc }
            if let params = function["parameters"] { declaration["parameters"] = params }
            return declaration
        }
    }
}
