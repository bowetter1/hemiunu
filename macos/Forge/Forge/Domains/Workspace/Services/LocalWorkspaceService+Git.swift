import Foundation

extension LocalWorkspaceService {
    // MARK: - Git Operations

    /// Ensure a project has an initialized git repository.
    @discardableResult
    func ensureGitRepository(project: String) async throws -> ShellResult {
        let dir = projectPath(project)
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path) {
            return ShellResult(exitCode: 0, output: "Git repository already initialized")
        }
        return try await exec("git init", cwd: dir)
    }

    /// Clone a GitHub repo into ~/Forge/projects/<name>/
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

    /// Git status in porcelain format for machine parsing
    func gitPorcelainStatus(project: String) async throws -> ShellResult {
        try await exec("git status --porcelain", cwd: projectPath(project))
    }

    /// Git commit all changes
    func gitCommit(project: String, message: String) async throws -> ShellResult {
        _ = try await ensureGitRepository(project: project)
        let dir = projectPath(project)
        _ = try await exec("git add -A", cwd: dir)
        let status = try await exec("git status --porcelain", cwd: dir)
        let hasChanges = !status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let head = try? await exec("git rev-parse --verify HEAD", cwd: dir)
        let hasCommits = head?.succeeded == true

        if !hasChanges && hasCommits {
            return ShellResult(exitCode: 0, output: "No changes to commit")
        }

        let normalized = message
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeMessage = normalized.isEmpty ? "Update" : String(normalized.prefix(120))
        let escaped = safeMessage.replacingOccurrences(of: "'", with: "'\\''")
        let allowEmptyFlag = hasChanges ? "" : " --allow-empty"
        return try await exec(
            "git commit -m '\(escaped)' --allow-empty-message\(allowEmptyFlag)",
            cwd: dir,
            env: [
                "GIT_AUTHOR_NAME": "Forge",
                "GIT_AUTHOR_EMAIL": "forge@local",
                "GIT_COMMITTER_NAME": "Forge",
                "GIT_COMMITTER_EMAIL": "forge@local",
            ]
        )
    }

    /// Git log — returns commits as PageVersion objects (oldest first, version 1-based)
    func gitVersions(project: String) async throws -> [PageVersion] {
        let dir = projectPath(project)
        // Use a control-character delimiter so the shell doesn't interpret separators.
        let result = try await exec("git log --format='%H%x1f%s%x1f%aI' --reverse", cwd: dir)
        guard result.succeeded else { return [] }

        return result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, line in
                let parts = line.components(separatedBy: "\u{1F}")
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
