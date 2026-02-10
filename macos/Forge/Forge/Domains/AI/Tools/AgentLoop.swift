import Foundation

/// Events emitted during an agent loop iteration
enum AgentEvent: Sendable {
    case thinking
    case toolStart(name: String, args: String)
    case toolDone(name: String, summary: String)
    case text(String)
    case error(String)
    case apiResponse(inputTokens: Int, outputTokens: Int)
}

/// Runs an agentic tool-use loop: call LLM → execute tools → repeat until text response
@MainActor
class AgentLoop {
    private let defaultMaxIterations = 10

    func run(
        userMessage: String,
        history: [AIMessage],
        systemPrompt: String,
        service: any AIService,
        executor: any ToolExecuting,
        tools overrideTools: [[String: Any]]? = nil,
        maxIterations overrideMax: Int? = nil,
        rawHistory: [[String: Any]]? = nil,
        onEvent: @escaping (AgentEvent) -> Void
    ) async throws -> AgentResult {
        let isAnthropic = service.provider == .claude
        let maxIterations = overrideMax ?? defaultMaxIterations
        var totalInput = 0
        var totalOutput = 0

        // Build initial message list — use raw history (with tool calls) if available
        nonisolated(unsafe) var messages: [[String: Any]]
        if let rawHistory, !rawHistory.isEmpty {
            // Raw history includes system prompt + full conversation with tool calls
            var msgs = rawHistory
            msgs.append(["role": "user", "content": userMessage])
            messages = msgs
        } else {
            messages = buildInitialMessages(
                history: history,
                userMessage: userMessage,
                systemPrompt: systemPrompt,
                isAnthropic: isAnthropic
            )
        }

        nonisolated(unsafe) let tools: [[String: Any]] = overrideTools ?? (isAnthropic
            ? ForgeTools.anthropicFormat()
            : ForgeTools.openAIFormat())

        for _ in 0..<maxIterations {
            guard !Task.isCancelled else { throw AIError.cancelled }

            onEvent(.thinking)

            let response = try await service.generateWithTools(
                messages: messages,
                systemPrompt: systemPrompt,
                tools: tools
            )

            totalInput += response.inputTokens
            totalOutput += response.outputTokens
            onEvent(.apiResponse(inputTokens: response.inputTokens, outputTokens: response.outputTokens))

            // No tool calls — we have a final text response
            if response.toolCalls.isEmpty {
                let text = response.text ?? ""
                onEvent(.text(text))
                // Append final assistant message to history
                messages.append(["role": "assistant", "content": text])
                return AgentResult(text: text, totalInputTokens: totalInput, totalOutputTokens: totalOutput, messages: messages)
            }

            // Emit tool start events
            for call in response.toolCalls {
                onEvent(.toolStart(name: call.name, args: call.arguments))
            }

            // Execute tool calls: priority tools first (sequential), then rest in parallel
            let priority = executor.priorityToolNames
            var toolResults: [(call: ToolCall, result: String)] = []

            // Partition into priority and normal calls
            let priorityCalls = response.toolCalls.filter { priority.contains($0.name) }
            let normalCalls = response.toolCalls.filter { !priority.contains($0.name) }

            // Priority tools run first, sequentially (e.g. create_project before create_file)
            for call in priorityCalls {
                do {
                    let result = try await executor.execute(call)
                    toolResults.append((call, result))
                } catch {
                    toolResults.append((call, "Error: \(error.localizedDescription)"))
                }
                onEvent(.toolDone(name: call.name, summary: summarize(toolResults.last!.result)))
            }

            // Normal tools run in parallel (or sequentially if only one)
            if normalCalls.count == 1 {
                let call = normalCalls[0]
                do {
                    let result = try await executor.execute(call)
                    toolResults.append((call, result))
                } catch {
                    toolResults.append((call, "Error: \(error.localizedDescription)"))
                }
            } else if normalCalls.count > 1 {
                let tasks: [Task<(ToolCall, String), Never>] = normalCalls.map { call in
                    nonisolated(unsafe) let exec = executor
                    return Task { @MainActor in
                        do {
                            let result = try await exec.execute(call)
                            return (call, result)
                        } catch {
                            return (call, "Error: \(error.localizedDescription)")
                        }
                    }
                }
                for task in tasks {
                    let result = await task.value
                    toolResults.append(result)
                }
            }

            // Emit tool done events (skip priority tools — already emitted above)
            for item in toolResults {
                if !priority.contains(item.0.name) {
                    onEvent(.toolDone(name: item.0.name, summary: summarize(item.1)))
                }
            }

            // Append assistant message + tool results to conversation
            let mappedResults = toolResults.map { (call: $0.0, result: $0.1) }
            if isAnthropic {
                appendAnthropicTurn(
                    messages: &messages,
                    response: response,
                    toolResults: mappedResults
                )
            } else {
                appendOpenAITurn(
                    messages: &messages,
                    response: response,
                    toolResults: mappedResults
                )
            }
        }

        onEvent(.error("Reached maximum iterations (\(maxIterations))"))
        return AgentResult(text: "I ran out of steps. Please try a more specific request.", totalInputTokens: totalInput, totalOutputTokens: totalOutput, messages: messages)
    }

    // MARK: - Message Building

    private func buildInitialMessages(
        history: [AIMessage],
        userMessage: String,
        systemPrompt: String,
        isAnthropic: Bool
    ) -> [[String: Any]] {
        if isAnthropic {
            // Anthropic: system is separate (handled by service), messages are user/assistant
            var msgs: [[String: Any]] = []
            for msg in history {
                msgs.append(["role": msg.role, "content": msg.content])
            }
            msgs.append(["role": "user", "content": userMessage])
            return msgs
        } else {
            // OpenAI: system message + history + user
            var msgs: [[String: Any]] = [
                ["role": "system", "content": systemPrompt]
            ]
            for msg in history {
                msgs.append(["role": msg.role, "content": msg.content])
            }
            msgs.append(["role": "user", "content": userMessage])
            return msgs
        }
    }

    /// Append assistant + tool_result messages in Anthropic format
    private func appendAnthropicTurn(
        messages: inout [[String: Any]],
        response: ToolResponse,
        toolResults: [(call: ToolCall, result: String)]
    ) {
        // Assistant message with tool_use blocks
        var contentBlocks: [[String: Any]] = []
        if let text = response.text, !text.isEmpty {
            contentBlocks.append(["type": "text", "text": text])
        }
        for call in response.toolCalls {
            let inputData = call.arguments.data(using: .utf8) ?? Data()
            let input = (try? JSONSerialization.jsonObject(with: inputData)) as? [String: Any] ?? [:]
            contentBlocks.append([
                "type": "tool_use",
                "id": call.id,
                "name": call.name,
                "input": input,
            ])
        }
        messages.append(["role": "assistant", "content": contentBlocks])

        // User message with tool_result blocks
        let resultBlocks: [[String: Any]] = toolResults.map { item in
            [
                "type": "tool_result",
                "tool_use_id": item.call.id,
                "content": item.result,
            ]
        }
        messages.append(["role": "user", "content": resultBlocks])
    }

    /// Append assistant + tool messages in OpenAI format
    private func appendOpenAITurn(
        messages: inout [[String: Any]],
        response: ToolResponse,
        toolResults: [(call: ToolCall, result: String)]
    ) {
        // Use raw message if available (preserves Gemini thought_signature and other provider fields)
        if let rawData = response.rawAssistantMessage,
           let rawMsg = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
            messages.append(rawMsg)
        } else {
            // Fallback: reconstruct from parsed fields
            let toolCallsPayload: [[String: Any]] = response.toolCalls.map { call in
                [
                    "id": call.id,
                    "type": "function",
                    "function": [
                        "name": call.name,
                        "arguments": call.arguments,
                    ] as [String: Any],
                ]
            }
            var assistantMsg: [String: Any] = [
                "role": "assistant",
                "tool_calls": toolCallsPayload,
            ]
            if let text = response.text, !text.isEmpty {
                assistantMsg["content"] = text
            }
            messages.append(assistantMsg)
        }

        // One "tool" message per result
        for item in toolResults {
            messages.append([
                "role": "tool",
                "tool_call_id": item.call.id,
                "content": item.result,
            ])
        }
    }

    // MARK: - Helpers

    private func summarize(_ text: String) -> String {
        if text.count <= 100 { return text }
        return String(text.prefix(97)) + "..."
    }
}
