import Foundation

extension LocalWorkspaceService {
    // MARK: - Deploy Operations

    /// Deploy to Railway
    func railwayDeploy(project: String, detach: Bool = true) async throws -> ShellResult {
        try await exec(
            "railway up\(detach ? " --detach" : "")",
            cwd: projectPath(project),
            timeout: 600
        )
    }

    /// Set Railway environment variables
    func railwaySetVars(project: String, vars: [String: String]) async throws -> ShellResult {
        let pairs = vars.map { "\($0.key)=\($0.value)" }.joined(separator: "\" --set \"")
        return try await exec(
            "railway variables --set \"\(pairs)\" --skip-deploys",
            cwd: projectPath(project)
        )
    }

    /// Get Railway domain
    func railwayDomain(project: String) async throws -> ShellResult {
        try await exec("railway domain", cwd: projectPath(project))
    }

}
