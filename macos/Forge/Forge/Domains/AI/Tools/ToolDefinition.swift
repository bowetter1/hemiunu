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

/// Tool schemas for Forge's file-management tools
enum ForgeTools {

    /// All tool definitions in OpenAI function-calling format (Groq, Codex, Gemini)
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
                    "name": "run_command",
                    "description": "Run a shell command in the project directory. Use for installing dependencies (npm install), building projects (npm run build), or other CLI tasks. The command runs in the project root with a 120-second timeout. Returns stdout+stderr and exit code.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The shell command to run (e.g. 'npm install', 'npm run build')",
                            ],
                        ],
                        "required": ["command"],
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
            [
                "type": "function",
                "function": [
                    "name": "search_images",
                    "description": "Search for high-quality stock photos via Pexels. Returns direct image URLs you can use in <img> tags. Use short, specific queries (2-4 words) for best results.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "Short search query (e.g. 'coffee shop interior', 'mountain landscape', 'team meeting')",
                            ],
                            "count": [
                                "type": "integer",
                                "description": "Number of images to return (1-5, default 3)",
                            ],
                        ],
                        "required": ["query"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "generate_image",
                    "description": "Generate an AI image from a text description using GPT-Image-1. The image is saved locally in the project's images/ folder. Use the returned path as src in <img> tags. Best for hero images, custom illustrations, or brand-specific visuals.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "prompt": [
                                "type": "string",
                                "description": "Detailed description of the image to generate (e.g. 'A warm cozy Swedish hotel room with wooden furniture, soft lighting, and a view of the archipelago')",
                            ],
                            "filename": [
                                "type": "string",
                                "description": "Filename for the saved image (e.g. 'hero.png', 'room.png'). Saved to images/ folder.",
                            ],
                        ],
                        "required": ["prompt"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "restyle_image",
                    "description": "Restyle an existing image while keeping its content. Downloads the reference image, then generates a new version with a different visual style. Only describe the desired STYLE, not the content.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "reference_url": [
                                "type": "string",
                                "description": "URL of the reference image to restyle",
                            ],
                            "style_prompt": [
                                "type": "string",
                                "description": "Style description ONLY (e.g. 'warm golden lighting, editorial photography, soft contrast'). Do NOT describe objects.",
                            ],
                            "filename": [
                                "type": "string",
                                "description": "Filename for the saved image (e.g. 'hero-restyled.png')",
                            ],
                        ],
                        "required": ["reference_url", "style_prompt"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "download_image",
                    "description": "Download an image from a URL and save it locally in the project's images/ folder. Use this to save stock photos, brand logos, or any web image for use in the website. Returns the local path to use in <img> tags.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "url": [
                                "type": "string",
                                "description": "The image URL to download",
                            ],
                            "filename": [
                                "type": "string",
                                "description": "Filename to save as (e.g. 'hero.jpg', 'logo.png')",
                            ],
                        ],
                        "required": ["url", "filename"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "take_screenshot",
                    "description": "Take a screenshot of the project's main HTML page rendered in a WebView. Returns an image description from visual analysis.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "width": [
                                "type": "integer",
                                "description": "Viewport width in pixels (default 1280)",
                            ],
                            "height": [
                                "type": "integer",
                                "description": "Viewport height in pixels (default 800)",
                            ],
                        ] as [String: Any],
                        "required": [String](),
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "review_screenshot",
                    "description": "Analyze a previously taken screenshot for visual quality, layout issues, and usability problems. Returns detailed feedback.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "focus": [
                                "type": "string",
                                "description": "What to focus on: 'layout', 'colors', 'typography', 'responsiveness', 'overall' (default: 'overall')",
                            ],
                        ] as [String: Any],
                        "required": [String](),
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
            "description": "Delegate a task to a sub-agent. The sub-agent will execute the task using its own tools and return a result. Available roles: coder (builds HTML/CSS/JS), researcher (web search + files), reviewer (read-only inspection), tester (screenshot + visual QA).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "role": [
                        "type": "string",
                        "enum": ["coder", "researcher", "reviewer", "tester"],
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
        tools.append([
            "name": "build_version",
            "description": "Build a version of the website using a specific AI builder. Call this multiple times in parallel to create different versions. Each version gets its own project workspace. Available builders: opus (Claude — polished, architectural), gemini (Gemini — analytical, research-driven), codex (GPT-5.2 Codex — fast, creative).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "builder": [
                        "type": "string",
                        "enum": ["opus", "gemini", "codex"],
                        "description": "Which AI builder to use for this version",
                    ] as [String: Any],
                    "version": [
                        "type": "integer",
                        "description": "Version number (1, 2, or 3)",
                    ] as [String: Any],
                    "instructions": [
                        "type": "string",
                        "description": "Build instructions including what to create",
                    ] as [String: Any],
                    "design_direction": [
                        "type": "string",
                        "description": "Unique creative direction for this version (e.g. 'Luxury minimalist aesthetic', 'Tech-forward and futuristic', 'Warm and community-focused')",
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["builder", "version", "instructions", "design_direction"],
            ] as [String: Any],
        ])
        return tools
    }

    /// Boss-mode tool definitions in OpenAI format (Gemini) — wraps boss tools for OpenAI-compatible APIs
    static func bossOpenAIFormat() -> [[String: Any]] {
        var tools = openAIFormat()
        tools.append([
            "type": "function",
            "function": [
                "name": "delegate_task",
                "description": "Delegate a task to a sub-agent. The sub-agent will execute the task using its own tools and return a result. Available roles: coder (builds HTML/CSS/JS), researcher (web search + files), reviewer (read-only inspection), tester (screenshot + visual QA).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "role": [
                            "type": "string",
                            "enum": ["coder", "researcher", "reviewer", "tester"],
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
            ] as [String: Any],
        ])
        tools.append([
            "type": "function",
            "function": [
                "name": "create_project",
                "description": "Create a new project workspace. Call this first if no project exists yet. The name should be a short kebab-case slug derived from the user's request (e.g. 'coffee-shop-site', 'portfolio-site').",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Short kebab-case project name (e.g. 'coffee-shop-site', 'restaurant-menu')",
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["name"],
                ] as [String: Any],
            ] as [String: Any],
        ])
        tools.append([
            "type": "function",
            "function": [
                "name": "update_checklist",
                "description": "Create or update the task checklist. Use this to break down the user's request into steps and track progress. Always call this before starting work.",
                "parameters": [
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
            ] as [String: Any],
        ])
        tools.append([
            "type": "function",
            "function": [
                "name": "build_version",
                "description": "Build a version of the website using a specific AI builder. Call this multiple times in parallel to create different versions. Each version gets its own project workspace. Available builders: opus (Claude — polished, architectural), gemini (Gemini — analytical, research-driven), codex (GPT-5.2 Codex — fast, creative).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "builder": [
                            "type": "string",
                            "enum": ["opus", "gemini", "codex"],
                            "description": "Which AI builder to use for this version",
                        ] as [String: Any],
                        "version": [
                            "type": "integer",
                            "description": "Version number (1, 2, or 3)",
                        ] as [String: Any],
                        "instructions": [
                            "type": "string",
                            "description": "Build instructions including what to create",
                        ] as [String: Any],
                        "design_direction": [
                            "type": "string",
                            "description": "Unique creative direction for this version (e.g. 'Luxury minimalist aesthetic', 'Tech-forward and futuristic', 'Warm and community-focused')",
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["builder", "version", "instructions", "design_direction"],
                ] as [String: Any],
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
                "name": "run_command",
                "description": "Run a shell command in the project directory. Use for installing dependencies (npm install), building projects (npm run build), or other CLI tasks. The command runs in the project root with a 120-second timeout. Returns stdout+stderr and exit code.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The shell command to run (e.g. 'npm install', 'npm run build')",
                        ],
                    ],
                    "required": ["command"],
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
            [
                "name": "search_images",
                "description": "Search for high-quality stock photos via Pexels. Returns direct image URLs you can use in <img> tags. Use short, specific queries (2-4 words) for best results.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Short search query (e.g. 'coffee shop interior', 'mountain landscape', 'team meeting')",
                        ],
                        "count": [
                            "type": "integer",
                            "description": "Number of images to return (1-5, default 3)",
                        ],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ],
            [
                "name": "generate_image",
                "description": "Generate an AI image from a text description using GPT-Image-1. The image is saved locally in the project's images/ folder. Use the returned path as src in <img> tags. Best for hero images, custom illustrations, or brand-specific visuals.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "prompt": [
                            "type": "string",
                            "description": "Detailed description of the image to generate",
                        ],
                        "filename": [
                            "type": "string",
                            "description": "Filename for the saved image (e.g. 'hero.png'). Saved to images/ folder.",
                        ],
                    ] as [String: Any],
                    "required": ["prompt"],
                ] as [String: Any],
            ],
            [
                "name": "restyle_image",
                "description": "Restyle an existing image while keeping its content. Downloads the reference image, then generates a new version with a different visual style. Only describe the desired STYLE, not the content.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "reference_url": [
                            "type": "string",
                            "description": "URL of the reference image to restyle",
                        ],
                        "style_prompt": [
                            "type": "string",
                            "description": "Style description ONLY (e.g. 'warm golden lighting, editorial photography'). Do NOT describe objects.",
                        ],
                        "filename": [
                            "type": "string",
                            "description": "Filename for the saved image (e.g. 'hero-restyled.png')",
                        ],
                    ] as [String: Any],
                    "required": ["reference_url", "style_prompt"],
                ] as [String: Any],
            ],
            [
                "name": "download_image",
                "description": "Download an image from a URL and save it locally in the project's images/ folder. Returns the local path to use in <img> tags.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "url": [
                            "type": "string",
                            "description": "The image URL to download",
                        ],
                        "filename": [
                            "type": "string",
                            "description": "Filename to save as (e.g. 'hero.jpg', 'logo.png')",
                        ],
                    ] as [String: Any],
                    "required": ["url", "filename"],
                ] as [String: Any],
            ],
            [
                "name": "take_screenshot",
                "description": "Take a screenshot of the project's main HTML page rendered in a WebView. Returns an image description from visual analysis.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "width": [
                            "type": "integer",
                            "description": "Viewport width in pixels (default 1280)",
                        ],
                        "height": [
                            "type": "integer",
                            "description": "Viewport height in pixels (default 800)",
                        ],
                    ] as [String: Any],
                    "required": [String](),
                ] as [String: Any],
            ],
            [
                "name": "review_screenshot",
                "description": "Analyze a previously taken screenshot for visual quality, layout issues, and usability problems. Returns detailed feedback.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "focus": [
                            "type": "string",
                            "description": "What to focus on: 'layout', 'colors', 'typography', 'responsiveness', 'overall' (default: 'overall')",
                        ],
                    ] as [String: Any],
                    "required": [String](),
                ] as [String: Any],
            ],
        ]
    }
}

// MARK: - Response Parsers

/// Parses non-streaming OpenAI-format responses (Groq, Codex, Gemini)
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

        // Preserve raw message so provider-specific fields (e.g. Gemini thought_signature) survive round-trips
        let rawMessage = try? JSONSerialization.data(withJSONObject: message)

        return ToolResponse(text: text, toolCalls: toolCalls, inputTokens: inputTokens, outputTokens: outputTokens, rawAssistantMessage: rawMessage)
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
