import Foundation

/// GitHub CLI (`gh`) wrapper for repo creation and push.
enum GitHubService {
    private static let ghPath = "/opt/homebrew/bin/gh"

    /// Whether `gh` CLI is installed
    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: ghPath)
    }

    /// Whether the user is logged in (`gh auth status`)
    static func isAuthenticated() async -> Bool {
        guard isAvailable else { return false }
        do {
            let result = try await runCLI(["auth", "status"])
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    /// Create a GitHub repo from the working directory and push.
    /// Returns the repo URL (e.g. "https://github.com/user/repo").
    static func createAndPush(name: String, isPrivate: Bool, cwd: URL) async throws -> String {
        // Ensure git repo exists with at least one commit
        try await ensureGitRepo(cwd: cwd)

        // gh repo create <name> --public/--private --source . --push
        let visibility = isPrivate ? "--private" : "--public"
        let result = try await runCLI(["repo", "create", name, visibility, "--source", ".", "--push"], cwd: cwd, timeout: 60)

        guard result.exitCode == 0 else {
            throw GitHubError.pushFailed(result.output)
        }

        // Parse repo URL from output
        let url = parseRepoURL(from: result.output) ?? "https://github.com/\(name)"

        // Save github.json
        let info: [String: Any] = [
            "repo": name,
            "url": url,
            "private": isPrivate,
            "created_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) {
            try? data.write(to: cwd.appendingPathComponent("github.json"))
        }

        return url
    }

    /// Push existing repo (subsequent pushes)
    static func push(cwd: URL) async throws -> String {
        let result = try await runGit(["push"], cwd: cwd)
        guard result.exitCode == 0 else {
            throw GitHubError.pushFailed(result.output)
        }
        return result.output
    }

    // MARK: - Private

    private static func ensureGitRepo(cwd: URL) async throws {
        let gitDir = cwd.appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: gitDir.path) {
            _ = try await runGit(["init"], cwd: cwd)
            _ = try await runGit(["add", "."], cwd: cwd)
            _ = try await runGit(["commit", "-m", "Initial commit"], cwd: cwd)
        } else {
            // Stage and commit any uncommitted changes
            let status = try await runGit(["status", "--porcelain"], cwd: cwd)
            if !status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try await runGit(["add", "."], cwd: cwd)
                _ = try await runGit(["commit", "-m", "Update"], cwd: cwd)
            }
        }
    }

    private static func parseRepoURL(from output: String) -> String? {
        // gh outputs the URL like: https://github.com/user/repo
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("https://github.com/") {
                return trimmed
            }
        }
        return nil
    }

    private static func runGit(_ args: [String], cwd: URL) async throws -> (exitCode: Int, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = cwd

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (Int(process.terminationStatus), output)
    }

    @discardableResult
    private static func runCLI(_ args: [String], cwd: URL? = nil, timeout: TimeInterval = 30) async throws -> (exitCode: Int, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (Int(process.terminationStatus), output)
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case pushFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .pushFailed(let detail):
            return "GitHub push failed: \(detail.prefix(200))"
        case .notAuthenticated:
            return "Not logged in to GitHub. Run `gh auth login` in Terminal."
        }
    }
}
