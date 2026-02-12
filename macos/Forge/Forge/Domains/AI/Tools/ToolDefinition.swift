import Foundation

/// Protocol for executing tool calls — allows swapping in BossToolExecutor
@MainActor
protocol ToolExecuting {
    func execute(_ call: ToolCall) async throws -> String
    /// Tool names that must execute before other tools in the same batch (e.g. create_project)
    var priorityToolNames: Set<String> { get }
}

extension ToolExecuting {
    var priorityToolNames: Set<String> { [] }
}

/// A tool call returned by an LLM
struct ToolCall: Sendable {
    let id: String
    let name: String
    let arguments: String // raw JSON string
}

/// Parsed response from a non-streaming API call
struct ToolResponse: Sendable {
    let text: String?
    let toolCalls: [ToolCall]
    let inputTokens: Int
    let outputTokens: Int
    /// Raw assistant message JSON — preserves provider-specific fields like Gemini thought_signature
    let rawAssistantMessage: Data?

    init(text: String?, toolCalls: [ToolCall], inputTokens: Int, outputTokens: Int, rawAssistantMessage: Data? = nil) {
        self.text = text
        self.toolCalls = toolCalls
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.rawAssistantMessage = rawAssistantMessage
    }
}

/// Result from a complete agent loop run
struct AgentResult: Sendable {
    let text: String
    let totalInputTokens: Int
    let totalOutputTokens: Int
    /// Full conversation messages including tool calls/results (for context caching)
    nonisolated(unsafe) let messages: [[String: Any]]
}

enum ForgeTools {}
