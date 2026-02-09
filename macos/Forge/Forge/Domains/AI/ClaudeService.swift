import Foundation

/// Claude (Anthropic) API service — native Anthropic streaming endpoint
/// Use modelOverride to select a specific model (e.g. "claude-opus-4-6" for builders)
final class ClaudeService: AIService, Sendable {
    let provider: AIProvider = .claude
    private let modelName: String
    private let maxTokens: Int
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(modelOverride: String? = nil, maxTokens: Int = 64000) {
        self.modelName = modelOverride ?? AIProvider.claude.modelName
        self.maxTokens = maxTokens
    }

    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.noAPIKey(provider: .claude)) }
        }

        let body = buildRequestBody(messages: messages, systemPrompt: systemPrompt)

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

    func generateWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ToolResponse {
        guard let apiKey = KeychainHelper.load(key: provider.keychainKey), !apiKey.isEmpty else {
            throw AIError.noAPIKey(provider: .claude)
        }

        var payload: [String: Any] = [
            "model": modelName,
            "system": systemPrompt,
            "messages": messages,
            "max_tokens": maxTokens,
        ]
        if !tools.isEmpty {
            payload["tools"] = tools
            payload["tool_choice"] = ["type": "auto"]
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.invalidResponse
        }

        #if DEBUG
        let toolNames = tools.compactMap { $0["name"] as? String }
        print("[Claude] generateWithTools — model: \(modelName), tools: \(toolNames), messages: \(messages.count)")
        #endif

        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        ]

        let (data, response) = try await HTTPClient.post(url: baseURL, headers: headers, body: body)

        #if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            let preview = String(raw.prefix(500))
            print("[Claude] Response (\(response.statusCode)): \(preview)")
        }
        #endif

        guard (200...299).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(status: response.statusCode, message: msg)
        }

        return try AnthropicToolResponseParser.parse(data)
    }

    private func buildRequestBody(messages: [AIMessage], systemPrompt: String) -> Data {
        let apiMessages = messages.map { msg in
            ["role": msg.role, "content": msg.content]
        }

        let payload: [String: Any] = [
            "model": modelName,
            "system": systemPrompt,
            "messages": apiMessages,
            "stream": true,
            "max_tokens": maxTokens,
        ]

        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}
