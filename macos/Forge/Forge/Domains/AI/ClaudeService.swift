import Foundation

/// Claude (Anthropic) API service — native Anthropic streaming endpoint
final class ClaudeService: AIService, @unchecked Sendable {
    let provider: AIProvider = .claude
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .claude)) }
        }

        let body: Data
        do {
            body = try buildRequestBody(messages: messages, systemPrompt: systemPrompt)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        ]

        return AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                do {
                    for try await chunk in HTTPClient.stream(url: baseURL, headers: headers, body: body) {
                        let lines = StreamingParser.splitSSELines(from: chunk, buffer: &buffer)
                        for line in lines {
                            if let content = StreamingParser.parseAnthropicChunk(line) {
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

    private func buildRequestBody(messages: [AIMessage], systemPrompt: String) throws -> Data {
        let apiMessages = messages.map { msg in
            ["role": msg.role, "content": msg.content]
        }

        let payload: [String: Any] = [
            "model": provider.modelName,
            "system": systemPrompt,
            "messages": apiMessages,
            "stream": true,
            "max_tokens": 8192,
        ]

        return try JSONSerialization.data(withJSONObject: payload)
    }
}
