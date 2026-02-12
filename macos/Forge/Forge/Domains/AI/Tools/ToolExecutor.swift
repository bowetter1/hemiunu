import Foundation

/// Executes tool calls against the local workspace.
@MainActor
struct ToolExecutor: ToolExecuting {
    let workspace: LocalWorkspaceService
    let projectName: String
    var onFileWrite: (() -> Void)?

    /// Execute a tool call and return the result as a string.
    func execute(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)

        switch call.name {
        case "list_files":
            return executeListFiles()

        case "read_file":
            guard let path = args["path"] as? String else {
                throw ToolError.missingParameter("path")
            }
            return try executeReadFile(path: path)

        case "create_file":
            guard let path = args["path"] as? String,
                  let content = args["content"] as? String else {
                throw ToolError.missingParameter("path and content")
            }
            return try executeCreateFile(path: path, content: content)

        case "edit_file":
            guard let path = args["path"] as? String,
                  let search = args["search"] as? String,
                  let replace = args["replace"] as? String else {
                throw ToolError.missingParameter("path, search, and replace")
            }
            return try executeEditFile(path: path, search: search, replace: replace)

        case "delete_file":
            guard let path = args["path"] as? String else {
                throw ToolError.missingParameter("path")
            }
            return try executeDeleteFile(path: path)

        case "run_command":
            guard let command = args["command"] as? String, !command.isEmpty else {
                throw ToolError.missingParameter("command")
            }
            return try await executeRunCommand(command: command)

        case "web_search":
            guard let query = args["query"] as? String else {
                throw ToolError.missingParameter("query")
            }
            return try await executeWebSearch(query: query)

        case "search_images":
            guard let query = args["query"] as? String else {
                throw ToolError.missingParameter("query")
            }
            let count = args["count"] as? Int ?? 3
            return try await executeSearchImages(query: query, count: min(max(count, 1), 5))

        case "generate_image":
            guard let prompt = args["prompt"] as? String else {
                throw ToolError.missingParameter("prompt")
            }
            let filename = args["filename"] as? String ?? "generated-\(UUID().uuidString.prefix(6)).png"
            return try await executeGenerateImage(prompt: prompt, filename: filename)

        case "restyle_image":
            guard let referenceURL = args["reference_url"] as? String,
                  let stylePrompt = args["style_prompt"] as? String else {
                throw ToolError.missingParameter("reference_url and style_prompt")
            }
            let filename = args["filename"] as? String ?? "restyled-\(UUID().uuidString.prefix(6)).png"
            return try await executeRestyleImage(referenceURL: referenceURL, stylePrompt: stylePrompt, filename: filename)

        case "download_image":
            guard let urlString = args["url"] as? String,
                  let filename = args["filename"] as? String else {
                throw ToolError.missingParameter("url and filename")
            }
            return try await executeDownloadImage(urlString: urlString, filename: filename)

        case "take_screenshot":
            let width = args["width"] as? Int ?? 1280
            let height = args["height"] as? Int ?? 800
            return executeTakeScreenshot(width: width, height: height)

        case "review_screenshot":
            let focus = args["focus"] as? String ?? "overall"
            return executeReviewScreenshot(focus: focus)

        // MARK: - Daytona Sandbox Tools

        case "sandbox_create":
            guard let name = args["name"] as? String else {
                throw ToolError.missingParameter("name")
            }
            let sandboxId = try await DaytonaService.createSandbox(name: name)
            return "Sandbox created. ID: \(sandboxId)"

        case "sandbox_upload":
            guard let sandboxId = args["sandbox_id"] as? String,
                  let files = args["files"] as? [[String: Any]] else {
                throw ToolError.missingParameter("sandbox_id and files")
            }
            let skipPrefixes = ["node_modules/", ".git/", ".next/"]
            let skipFiles: Set<String> = ["build-log.md", "agent-name.txt", "brief.md", "project-name.txt"]
            var uploaded = 0
            for fileEntry in files {
                guard let remotePath = fileEntry["path"] as? String,
                      let projectPath = fileEntry["project_path"] as? String else { continue }
                if skipPrefixes.contains(where: { projectPath.hasPrefix($0) }) { continue }
                if skipFiles.contains(projectPath) { continue }
                let localURL = workspace.projectPath(projectName).appendingPathComponent(projectPath)
                guard let data = try? Data(contentsOf: localURL) else { continue }
                try await DaytonaService.uploadFile(sandboxId: sandboxId, remotePath: remotePath, localData: data)
                uploaded += 1
            }
            return "Uploaded \(uploaded) files to sandbox \(sandboxId)."

        case "sandbox_exec":
            guard let sandboxId = args["sandbox_id"] as? String,
                  let command = args["command"] as? String else {
                throw ToolError.missingParameter("sandbox_id and command")
            }
            let timeout = args["timeout"] as? Int ?? 120
            let result = try await DaytonaService.exec(sandboxId: sandboxId, command: command, timeout: timeout)
            return "Exit code: \(result.exitCode)\n\(result.output)"

        case "sandbox_preview_url":
            guard let sandboxId = args["sandbox_id"] as? String,
                  let port = args["port"] as? Int else {
                throw ToolError.missingParameter("sandbox_id and port")
            }
            return DaytonaService.previewURL(sandboxId: sandboxId, port: port)

        case "sandbox_stop":
            guard let sandboxId = args["sandbox_id"] as? String else {
                throw ToolError.missingParameter("sandbox_id")
            }
            try await DaytonaService.stopSandbox(id: sandboxId)
            return "Sandbox \(sandboxId) stopped."

        default:
            throw ToolError.unknownTool(call.name)
        }
    }
}
