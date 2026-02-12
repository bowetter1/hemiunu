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

        default:
            throw ToolError.unknownTool(call.name)
        }
    }
}
