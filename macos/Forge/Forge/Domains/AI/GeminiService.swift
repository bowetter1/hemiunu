import Foundation

/// Gemini API service — OpenAI-compatible endpoint
/// Use modelOverride to select a specific model (e.g. "gemini-3-pro-preview" for builders)
final class GeminiService: AIService, Sendable {
    let provider: AIProvider = .gemini
    private let modelName: String
    private let maxTokens: Int
    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!

    init(modelOverride: String? = nil, maxTokens: Int = 8192) {
        self.modelName = modelOverride ?? AIProvider.gemini.modelName
        self.maxTokens = maxTokens
    }

    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .gemini)) }
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

    func generateWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ToolResponse {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            throw AIError.noAPIKey(provider: .gemini)
        }

        var payload: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        if !tools.isEmpty {
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.invalidResponse
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]

        let (data, response) = try await HTTPClient.post(url: baseURL, headers: headers, body: body)
        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return try OpenAIToolResponseParser.parse(data)
    }

    private func buildRequestBody(messages: [AIMessage], systemPrompt: String) -> Data {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in messages {
            apiMessages.append(["role": msg.role, "content": msg.content])
        }

        let payload: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": maxTokens,
        ]

        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}
