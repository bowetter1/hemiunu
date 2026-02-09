import Foundation

/// Protocol for executing tool calls — allows swapping in BossToolExecutor
@MainActor
protocol ToolExecuting {
    func execute(_ call: ToolCall) async throws -> String
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
}

/// Result from a complete agent loop run
struct AgentResult: Sendable {
    let text: String
    let totalInputTokens: Int
    let totalOutputTokens: Int
}

/// Tool schemas for Forge's file-management tools
enum ForgeTools {

    /// All tool definitions in OpenAI function-calling format (Cerebras, Groq)
    static func openAIFormat() -> [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "list_files",
                    "description": "List all files in the project directory (recursive). Returns file paths and sizes.",
                    "parameters": [
                        "type": "object",
                        "properties": [String: Any](),
                        "required": [String](),
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "read_file",
                    "description": "Read the contents of a file in the project.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file (e.g. 'index.html', 'css/style.css')",
                            ],
                        ],
                        "required": ["path"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_file",
                    "description": "Create or overwrite a file in the project with the given content.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path for the new file (e.g. 'contact.html')",
                            ],
                            "content": [
                                "type": "string",
                                "description": "The full file content to write",
                            ],
                        ],
                        "required": ["path", "content"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "edit_file",
                    "description": "Edit a file by replacing a specific string with new content. The search string must match exactly.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file to edit",
                            ],
                            "search": [
                                "type": "string",
                                "description": "The exact string to find in the file",
                            ],
                            "replace": [
                                "type": "string",
                                "description": "The replacement string",
                            ],
                        ],
                        "required": ["path", "search", "replace"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "delete_file",
                    "description": "Delete a file from the project.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file to delete",
                            ],
                        ],
                        "required": ["path"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "web_search",
                    "description": "Search the web using Google. Use this to find images, information, URLs, or anything you need from the internet. Returns text with source URLs.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "The search query (e.g. 'mountain landscape photo high resolution', 'tailwind css cdn link')",
                            ],
                        ],
                        "required": ["query"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
    }

    /// Boss-mode tool definitions in Anthropic format — includes delegate_task + update_checklist
    static func bossAnthropicFormat() -> [[String: Any]] {
        var tools = anthropicFormat()
        tools.append([
            "name": "delegate_task",
            "description": "Delegate a task to a sub-agent. The sub-agent will execute the task using its own tools and return a result. Available roles: coder (file operations), researcher (web search + file read/create), reviewer (read-only file inspection).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "role": [
                        "type": "string",
                        "enum": ["coder", "researcher", "reviewer"],
                        "description": "The sub-agent role to delegate to",
                    ] as [String: Any],
                    "instructions": [
                        "type": "string",
                        "description": "Detailed instructions for the sub-agent",
                    ],
                    "context": [
                        "type": "string",
                        "description": "Optional context from previous steps (e.g. file contents, search results)",
                    ],
                ] as [String: Any],
                "required": ["role", "instructions"],
            ] as [String: Any],
        ])
        tools.append([
            "name": "create_project",
            "description": "Create a new project workspace. Call this first if no project exists yet. The name should be a short kebab-case slug derived from the user's request (e.g. 'coffee-shop-site', 'portfolio-site').",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": [
                        "type": "string",
                        "description": "Short kebab-case project name (e.g. 'coffee-shop-site', 'restaurant-menu')",
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["name"],
            ] as [String: Any],
        ])
        tools.append([
            "name": "update_checklist",
            "description": "Create or update the task checklist. Use this to break down the user's request into steps and track progress. Always call this before starting work.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "items": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "step": ["type": "string", "description": "Description of this step"] as [String: Any],
                                "status": [
                                    "type": "string",
                                    "enum": ["pending", "in_progress", "done", "error"],
                                    "description": "Current status of this step",
                                ] as [String: Any],
                            ] as [String: Any],
                            "required": ["step", "status"],
                        ] as [String: Any],
                        "description": "List of checklist items with their status",
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["items"],
            ] as [String: Any],
        ])
        return tools
    }

    /// All tool definitions in Anthropic format (Claude)
    static func anthropicFormat() -> [[String: Any]] {
        [
            [
                "name": "list_files",
                "description": "List all files in the project directory (recursive). Returns file paths and sizes.",
                "input_schema": [
                    "type": "object",
                    "properties": [String: Any](),
                    "required": [String](),
                ] as [String: Any],
            ],
            [
                "name": "read_file",
                "description": "Read the contents of a file in the project.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Relative path to the file (e.g. 'index.html', 'css/style.css')",
                        ],
                    ],
                    "required": ["path"],
                ] as [String: Any],
            ],
            [
                "name": "create_file",
                "description": "Create or overwrite a file in the project with the given content.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Relative path for the new file (e.g. 'contact.html')",
                        ],
                        "content": [
                            "type": "string",
                            "description": "The full file content to write",
                        ],
                    ],
                    "required": ["path", "content"],
                ] as [String: Any],
            ],
            [
                "name": "edit_file",
                "description": "Edit a file by replacing a specific string with new content. The search string must match exactly.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Relative path to the file to edit",
                        ],
                        "search": [
                            "type": "string",
                            "description": "The exact string to find in the file",
                        ],
                        "replace": [
                            "type": "string",
                            "description": "The replacement string",
                        ],
                    ],
                    "required": ["path", "search", "replace"],
                ] as [String: Any],
            ],
            [
                "name": "delete_file",
                "description": "Delete a file from the project.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Relative path to the file to delete",
                        ],
                    ],
                    "required": ["path"],
                ] as [String: Any],
            ],
            [
                "name": "web_search",
                "description": "Search the web using Google. Use this to find images, information, URLs, or anything you need from the internet. Returns text with source URLs.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query (e.g. 'mountain landscape photo high resolution', 'tailwind css cdn link')",
                        ],
                    ],
                    "required": ["query"],
                ] as [String: Any],
            ],
        ]
    }
}

// MARK: - Response Parsers

/// Parses non-streaming OpenAI-format responses (Cerebras, Groq)
enum OpenAIToolResponseParser {
    static func parse(_ data: Data) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw AIError.invalidResponse
        }

        let text = message["content"] as? String

        var toolCalls: [ToolCall] = []
        if let calls = message["tool_calls"] as? [[String: Any]] {
            for call in calls {
                guard let id = call["id"] as? String,
                      let function = call["function"] as? [String: Any],
                      let name = function["name"] as? String else { continue }
                let arguments = function["arguments"] as? String ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: arguments))
            }
        }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["prompt_tokens"] as? Int ?? 0
        let outputTokens = usage?["completion_tokens"] as? Int ?? 0

        return ToolResponse(text: text, toolCalls: toolCalls, inputTokens: inputTokens, outputTokens: outputTokens)
    }
}

/// Parses non-streaming Anthropic-format responses (Claude)
enum AnthropicToolResponseParser {
    static func parse(_ data: Data) throws -> ToolResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }

        var text: String?
        var toolCalls: [ToolCall] = []

        for block in content {
            guard let type = block["type"] as? String else { continue }
            switch type {
            case "text":
                let t = block["text"] as? String ?? ""
                text = (text ?? "") + t
            case "tool_use":
                guard let id = block["id"] as? String,
                      let name = block["name"] as? String else { continue }
                let input = block["input"] as? [String: Any] ?? [:]
                let argsData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
                let argsString = String(data: argsData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: argsString))
            default:
                break
            }
        }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        return ToolResponse(text: text, toolCalls: toolCalls, inputTokens: inputTokens, outputTokens: outputTokens)
    }
}
