import Foundation

/// Errors during tool execution.
enum ToolError: LocalizedError {
    case missingParameter(String)
    case missingAPIKey(String)
    case unknownTool(String)
    case searchStringNotFound(path: String, search: String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .missingAPIKey(let detail):
            return "Missing API key: \(detail)"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .searchStringNotFound(let path, let search):
            return "Search string not found in \(path): \"\(search)\""
        }
    }
}
