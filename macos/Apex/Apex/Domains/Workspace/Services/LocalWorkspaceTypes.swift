import Foundation

// MARK: - Data Types

struct ShellResult {
    let exitCode: Int
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

struct FilePatch {
    let path: String
    let operation: PatchOperation

    enum PatchOperation {
        case replace(find: String, with: String)
        case write(content: String)
        case delete
    }
}

struct GitHubRepo: Identifiable {
    let fullName: String
    let description: String
    let stars: Int
    let url: String
    let cloneUrl: String
    let updatedAt: String
    let language: String
    let license: String?

    var id: String { fullName }
}

struct PipelineResult {
    var cloneOutput: String = ""
    var patchCount: Int = 0
    var installOutput: String = ""
    var buildOutput: String = ""
    var deployOutput: String = ""
    var liveUrl: String = ""
}

enum PipelineStep: String {
    case cloning = "Cloning repository..."
    case patching = "Applying patches..."
    case installing = "Installing dependencies..."
    case building = "Building project..."
    case settingVars = "Setting environment variables..."
    case deploying = "Deploying to Railway..."
    case gettingDomain = "Getting live URL..."
    case done = "Done!"
}

enum WorkspaceError: LocalizedError {
    case invalidURL
    case githubSearchFailed
    case cloneFailed(String)
    case installFailed(String)
    case buildFailed(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .githubSearchFailed: return "GitHub search failed"
        case .cloneFailed(let output): return "Clone failed: \(output)"
        case .installFailed(let output): return "Install failed: \(output)"
        case .buildFailed(let output): return "Build failed: \(output)"
        case .processLaunchFailed(let msg): return "Process launch failed: \(msg)"
        }
    }
}

