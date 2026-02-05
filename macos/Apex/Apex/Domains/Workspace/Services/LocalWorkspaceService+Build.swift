import Foundation

extension LocalWorkspaceService {
    // MARK: - Build Operations

    /// npm install in a project
    func npmInstall(project: String, flags: String = "--legacy-peer-deps") async throws -> ShellResult {
        try await exec("npm install \(flags)", cwd: projectPath(project))
    }

    /// npm run build
    func npmBuild(project: String, maxMemory: Int = 4096) async throws -> ShellResult {
        try await exec(
            "NODE_OPTIONS='--max-old-space-size=\(maxMemory)' npm run build",
            cwd: projectPath(project),
            timeout: 300
        )
    }

    /// npm run dev (returns immediately, server runs in background)
    func npmDev(project: String, port: Int = 3000) async throws -> ShellResult {
        try await exec(
            "PORT=\(port) npm run dev &",
            cwd: projectPath(project),
            timeout: 5
        )
    }

}
