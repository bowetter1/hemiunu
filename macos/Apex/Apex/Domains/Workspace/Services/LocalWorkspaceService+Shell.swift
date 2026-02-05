import Foundation

extension LocalWorkspaceService {
    // MARK: - Shell Execution

    /// Run a shell command and return result
    func exec(
        _ command: String,
        cwd: URL? = nil,
        timeout: TimeInterval = 120,
        env: [String: String]? = nil
    ) async throws -> ShellResult {
        let result: ShellResult = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = pipe
                process.standardError = pipe

                if let cwd = cwd {
                    process.currentDirectoryURL = cwd
                }

                // Inherit user PATH + add common tool locations
                var environment = ProcessInfo.processInfo.environment
                let extraPaths = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "/usr/local/share/npm/bin",
                    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/v20/bin",
                    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.railway/bin",
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

                // Timeout
                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )

                process.waitUntilExit()
                timeoutWorkItem.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
}
