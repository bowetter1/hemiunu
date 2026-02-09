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
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]
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

            process.terminationHandler = { terminatedProcess in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: ShellResult(
                    exitCode: Int(terminatedProcess.terminationStatus),
                    output: output
                ))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: WorkspaceError.processLaunchFailed(error.localizedDescription))
                return
            }

            // Timeout — terminate process if still running
            Task.detached {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    process.terminate()
                }
            }
        }
        lastOutput = result.output
        return result
    }
}
