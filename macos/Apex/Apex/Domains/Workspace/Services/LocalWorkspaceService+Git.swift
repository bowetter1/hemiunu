import Foundation

extension LocalWorkspaceService {
    // MARK: - Git Operations

    /// Clone a GitHub repo into ~/Apex/projects/<name>/
    func cloneRepo(url: String, name: String, branch: String = "main") async throws -> ShellResult {
        let dest = projectPath(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        return try await exec("git clone --branch \(branch) --single-branch \(url) \(dest.path)")
    }

    /// Git status for a project
    func gitStatus(project: String) async throws -> ShellResult {
        try await exec("git status", cwd: projectPath(project))
    }

    /// Git commit all changes
    func gitCommit(project: String, message: String) async throws -> ShellResult {
        let dir = projectPath(project)
        _ = try await exec("git add -A", cwd: dir)
        // Escape message for shell safety (single-quote wrapping with internal quote escaping)
        let escaped = message.replacingOccurrences(of: "'", with: "'\\''")
        return try await exec("git commit -m '\(escaped)' --allow-empty-message", cwd: dir)
    }

    /// Git log — returns commits as PageVersion objects (oldest first, version 1-based)
    func gitVersions(project: String) async throws -> [PageVersion] {
        let dir = projectPath(project)
        let result = try await exec("git log --format=%H||%s||%aI --reverse", cwd: dir)
        guard result.succeeded else { return [] }

        return result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, line in
                let parts = line.components(separatedBy: "||")
                guard parts.count >= 3, !parts[0].isEmpty else { return nil }
                return PageVersion(
                    id: parts[0],
                    version: index + 1,
                    instruction: parts[1].isEmpty ? nil : parts[1],
                    createdAt: parts[2]
                )
            }
    }

    /// Restore workspace files to a specific git commit
    func gitRestore(project: String, commitHash: String) async throws {
        let dir = projectPath(project)
        _ = try await exec("git checkout \(commitHash) -- .", cwd: dir)
    }

}
