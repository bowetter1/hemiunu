import Foundation

/// Together AI service — OpenAI-compatible streaming endpoint
final class TogetherService: AIService, @unchecked Sendable {
    let provider: AIProvider = .together
    private let baseURL = URL(string: "https://api.together.xyz/v1/chat/completions")!

    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .together)) }
        }

        let body = buildRequestBody(messages: messages, systemPrompt: systemPrompt)

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
                            if let content = StreamingParser.parseOpenAIChunk(line) {
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

    private func buildRequestBody(messages: [AIMessage], systemPrompt: String) -> Data {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in messages {
            apiMessages.append(["role": msg.role, "content": msg.content])
        }

        let payload: [String: Any] = [
            "model": provider.modelName,
            "messages": apiMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 8192,
        ]

        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}
