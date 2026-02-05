import Foundation

/// Parses Server-Sent Events (SSE) from AI API streaming responses
enum StreamingParser {

    // MARK: - OpenAI-compatible format (Groq)

    /// Parse an SSE data chunk in OpenAI format → extract content delta
    static func parseOpenAIChunk(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data: ") else { return nil }
        let jsonStr = String(trimmed.dropFirst(6))
        guard jsonStr != "[DONE]" else { return nil }

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    // MARK: - Anthropic format (Claude)

    /// Parse an SSE data chunk in Anthropic format → extract content delta
    static func parseAnthropicChunk(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data: ") else { return nil }
        let jsonStr = String(trimmed.dropFirst(6))

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let eventType = json["type"] as? String

        // content_block_delta contains the text
        if eventType == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }

        // Check for errors
        if eventType == "error",
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            // Return nil but the caller should handle error events separately
            print("[StreamingParser] Anthropic error: \(message)")
        }

        return nil
    }

    // MARK: - Generic SSE line splitter

    /// Split raw SSE data into individual lines, handling partial chunks
    static func splitSSELines(from data: Data, buffer: inout String) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        buffer += text

        var lines: [String] = []
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}
