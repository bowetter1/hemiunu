import Foundation

/// Protocol for AI services that support streaming text generation
protocol AIService: Sendable {
    var provider: AIProvider { get }

    /// Generate a streaming response from chat messages
    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error>

    /// Generate a non-streaming response with tool use support.
    /// Messages are raw dictionaries because OpenAI and Anthropic have different shapes
    /// for tool call/result messages.
    func generateWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ToolResponse
}

/// A message in the AI conversation (provider-agnostic)
struct AIMessage: Sendable {
    let role: String // "user" or "assistant"
    let content: String
}
