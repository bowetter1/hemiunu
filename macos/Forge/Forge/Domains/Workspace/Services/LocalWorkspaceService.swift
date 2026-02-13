import Foundation
import Observation

/// Local workspace service — manages project files at ~/Forge/projects/<name>/
@MainActor
@Observable
class LocalWorkspaceService {
    static let shared = LocalWorkspaceService()

    /// Root directory for all local projects
    let rootDirectory: URL

    var isRunning = false
    var lastOutput: String = ""
    var activeProcess: String?
    var serverProcess: Process?
    var serverPort: Int?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        rootDirectory = home.appendingPathComponent("Forge/projects")
        ensureRootExists()
    }

    // MARK: - Directory Management

    /// Ensure ~/Forge/projects/ exists
    private func ensureRootExists() {
        try? FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Get the local path for a project
    func projectPath(_ name: String) -> URL {
        rootDirectory.appendingPathComponent(name)
    }

    /// Resolve and validate that a file path stays within the project directory.
    /// Prevents path traversal attacks (e.g. "../../.ssh/id_rsa").
    func validatedPath(project: String, path: String) throws -> URL {
        let projectDir = projectPath(project).standardizedFileURL
        let resolved = projectDir.appendingPathComponent(path).standardizedFileURL
        guard resolved.path.hasPrefix(projectDir.path + "/") || resolved.path == projectDir.path else {
            throw WorkspaceError.pathOutsideProject(path)
        }
        return resolved
    }

    /// Check if a project directory exists locally
    func projectExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: projectPath(name).path)
    }

    /// Create a new project directory
    func createProject(name: String) throws -> URL {
        let path = projectPath(name)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    /// List all local projects
    func listProjects() -> [LocalProject] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else { return nil }

            let hasPackageJson = fm.fileExists(atPath: url.appendingPathComponent("package.json").path)
            let hasGit = fm.fileExists(atPath: url.appendingPathComponent(".git").path)
            let hasDockerfile = fm.fileExists(atPath: url.appendingPathComponent("Dockerfile").path)

            return LocalProject(
                name: url.lastPathComponent,
                path: url,
                modifiedAt: values.contentModificationDate ?? Date.distantPast,
                hasPackageJson: hasPackageJson,
                hasGit: hasGit,
                hasDockerfile: hasDockerfile
            )
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
