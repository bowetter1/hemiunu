import Foundation

extension ForgeTools {
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
            [
                "type": "function",
                "function": [
                    "name": "sandbox_create",
                    "description": "Create a public Daytona sandbox. Returns the sandbox ID.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "Name for the sandbox (e.g. 'my-site-deploy')",
                            ],
                        ],
                        "required": ["name"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "sandbox_upload",
                    "description": "Upload project files to a Daytona sandbox. Pass an array of files to upload. Each entry: path = destination in sandbox, project_path = relative path in the local project. Returns count of uploaded files.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "sandbox_id": [
                                "type": "string",
                                "description": "The sandbox ID",
                            ],
                            "files": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "path": ["type": "string", "description": "Destination path in sandbox"] as [String: Any],
                                        "project_path": ["type": "string", "description": "Relative path in the local project"] as [String: Any],
                                    ] as [String: Any],
                                    "required": ["path", "project_path"],
                                ] as [String: Any],
                                "description": "Files to upload",
                            ] as [String: Any],
                        ] as [String: Any],
                        "required": ["sandbox_id", "files"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "sandbox_exec",
                    "description": "Run a shell command in a Daytona sandbox. Returns stdout+stderr and exit code. Use for npm install, npm run build, starting servers, debugging.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "sandbox_id": [
                                "type": "string",
                                "description": "The sandbox ID",
                            ],
                            "command": [
                                "type": "string",
                                "description": "The shell command to run",
                            ],
                        ],
                        "required": ["sandbox_id", "command"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "sandbox_preview_url",
                    "description": "Get the public preview URL for a Daytona sandbox on a given port.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "sandbox_id": [
                                "type": "string",
                                "description": "The sandbox ID",
                            ],
                            "port": [
                                "type": "integer",
                                "description": "The port number (e.g. 3000)",
                            ],
                        ],
                        "required": ["sandbox_id", "port"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            [
                "type": "function",
                "function": [
                    "name": "sandbox_stop",
                    "description": "Stop a Daytona sandbox.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "sandbox_id": [
                                "type": "string",
                                "description": "The sandbox ID",
                            ],
                        ],
                        "required": ["sandbox_id"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
    }


    /// Boss-mode tool definitions in OpenAI format (Gemini) — wraps boss tools for OpenAI-compatible APIs
    static func bossOpenAIFormat() -> [[String: Any]] {
        var tools = openAIFormat()
        tools.append([
            "type": "function",
            "function": [
                "name": "delegate_task",
                "description": "Delegate a task to a sub-agent. The sub-agent will execute the task using its own tools and return a result. Available roles: coder (builds HTML/CSS/JS), reviewer (read-only inspection), tester (screenshot + visual QA), deployer (deploys versions to sandbox).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "role": [
                            "type": "string",
                            "enum": ["coder", "reviewer", "tester", "deployer"],
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
        tools.append([
            "type": "function",
            "function": [
                "name": "deploy_to_sandbox",
                "description": "Deploy a version of the project to a public Daytona sandbox. An AI agent will create a sandbox, upload project files, install dependencies, fix any issues, and start a server. Returns the public preview URL.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "version": [
                            "type": "string",
                            "description": "Which version to deploy (e.g. 'v1', 'v2')",
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["version"],
                ] as [String: Any],
            ] as [String: Any],
        ])
        return tools
    }
}
