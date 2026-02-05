import Foundation

extension BossService {
    // MARK: - Streaming Process Execution (non-Claude agents)

    func streamExec(
        executable: String,
        arguments: [String],
        cwd: URL?,
        authToken: String? = nil,
        apiURL: String? = nil,
        extraEnv: [String: String] = [:],
        onLine: @escaping (String) -> Void,
        onStderr: ((String) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let process = Process()
                let stdout = Pipe()
                let stderr = Pipe()

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = stdout
                process.standardError = stderr

                if let cwd {
                    process.currentDirectoryURL = cwd
                }

                var env = ProcessInfo.processInfo.environment
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let extraPaths = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "\(home)/.local/bin",
                    "\(home)/.nvm/versions/node/v20/bin",
                    "\(home)/.railway/bin",
                ]
                let existingPath = env["PATH"] ?? "/usr/bin:/bin"
                env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
                env["TERM"] = "dumb"
                env["NO_COLOR"] = "1"

                if let token = authToken, !token.isEmpty {
                    env["APEX_AUTH_TOKEN"] = token
                }
                if let url = apiURL, !url.isEmpty {
                    env["APEX_API_URL"] = url
                }
                for (key, value) in extraEnv {
                    env[key] = value
                }

                process.environment = env

                DispatchQueue.main.async {
                    self?.runningProcess = process
                }

                // Track last output time for idle detection (agents that forget apex_done)
                let lastOutputLock = NSLock()
                var lastOutputTime = Date()

                let handle = stdout.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    lastOutputLock.lock()
                    lastOutputTime = Date()
                    lastOutputLock.unlock()
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines)
                        for line in lines where !line.isEmpty {
                            onLine(line)
                        }
                    }
                }

                // Collect stderr for error reporting and optional logging
                let stderrLock = NSLock()
                var stderrChunks: [String] = []
                let errHandle = stderr.fileHandleForReading
                errHandle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    lastOutputLock.lock()
                    lastOutputTime = Date()
                    lastOutputLock.unlock()
                    if let text = String(data: data, encoding: .utf8) {
                        stderrLock.lock()
                        stderrChunks.append(text)
                        stderrLock.unlock()
                        onStderr?(text)
                    }
                }

                do {
                    try process.run()
                    BossPIDFile.add(process.processIdentifier)
                } catch {
                    continuation.resume(throwing: BossError.launchFailed(error.localizedDescription))
                    return
                }

                // Poll for process exit, done.signal, or idle+checklist-complete
                let doneSignalPath = cwd?.appendingPathComponent("done.signal").path
                let checklistPath = cwd?.appendingPathComponent("checklist.md")
                let idleTimeout: TimeInterval = 15

                while process.isRunning {
                    // 1. Explicit done signal from apex_done tool
                    if let path = doneSignalPath,
                       FileManager.default.fileExists(atPath: path) {
                        process.terminate()
                        process.waitUntilExit()
                        break
                    }

                    // 2. Fallback: agent idle + checklist fully complete
                    lastOutputLock.lock()
                    let idle = Date().timeIntervalSince(lastOutputTime)
                    lastOutputLock.unlock()

                    if idle > idleTimeout,
                       let clPath = checklistPath,
                       let checklist = try? String(contentsOf: clPath, encoding: .utf8),
                       !checklist.isEmpty {
                        let unchecked = checklist.components(separatedBy: .newlines)
                            .filter { $0.contains("- [ ]") }
                        if unchecked.isEmpty {
                            // All checklist items done — agent forgot apex_done
                            process.terminate()
                            process.waitUntilExit()
                            break
                        }
                    }

                    Thread.sleep(forTimeInterval: 0.5)
                }

                handle.readabilityHandler = nil
                errHandle.readabilityHandler = nil
                BossPIDFile.remove(process.processIdentifier)

                let status = process.terminationStatus
                // Exit 0 = normal, 15/-15 = SIGTERM from stop()/done.signal, 2 = Kimi CLI normal exit
                if status == 0 || status == 15 || status == -15 || status == 2 {
                    continuation.resume()
                } else {
                    stderrLock.lock()
                    let errText = stderrChunks.joined()
                    stderrLock.unlock()
                    continuation.resume(throwing: BossError.exitCode(Int(status), errText.isEmpty ? "Process exited with code \(status)" : errText))
                }
            }
        }
    }

}
