import Foundation

extension LocalWorkspaceService {
    // MARK: - Shell Execution

    /// Run a command with explicit arguments (safe from shell injection)
    func run(
        _ executable: String,
        arguments: [String] = [],
        cwd: URL? = nil,
        timeout: TimeInterval = 120,
        env: [String: String]? = nil
    ) async throws -> ShellResult {
        let result: ShellResult = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                if let cwd = cwd {
                    process.currentDirectoryURL = cwd
                }

                var environment = ProcessInfo.processInfo.environment
                let extraPaths = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "/usr/local/share/npm/bin",
                    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/v20/bin",
                ]
                let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
                environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")

                if let env = env {
                    for (key, value) in env {
                        environment[key] = value
                    }
                }
                process.environment = environment

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: WorkspaceError.processLaunchFailed(error.localizedDescription))
                    return
                }

                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )

                let data = pipe.fileHandleForReading.readDataToEndOfFile()

                process.waitUntilExit()
                timeoutWorkItem.cancel()

                let output = String(data: data, encoding: .utf8) ?? ""

                continuation.resume(returning: ShellResult(
                    exitCode: Int(process.terminationStatus),
                    output: output
                ))
            }
        }
        lastOutput = result.output
        return result
    }

    /// Convenience: find an executable in common paths
    static func which(_ name: String) -> String {
        let candidates = [
            "/usr/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/bin/env"
    }

    /// Path to git executable
    static let gitPath: String = which("git")

    /// Path to python3 executable
    static let python3Path: String = which("python3")
}
