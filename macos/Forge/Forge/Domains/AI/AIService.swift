import Foundation

/// Protocol for AI services that support streaming text generation
protocol AIService: Sendable {
    var provider: AIProvider { get }

    /// Generate a streaming response from chat messages
    func generate(
        messages: [AIMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error>
}

/// A message in the AI conversation (provider-agnostic)
struct AIMessage: Sendable {
    let role: String // "user" or "assistant"
    let content: String
}
