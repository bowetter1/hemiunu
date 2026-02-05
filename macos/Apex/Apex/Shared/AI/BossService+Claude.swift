import Foundation

extension BossService {
    // MARK: - Claude Persistent Process

    /// Send a message to Claude via the persistent stream-json process
    func sendClaude(
        message: String,
        cliPath: String,
        workingDirectory: URL?,
        vector: String?,
        onLine: @escaping (String) -> Void
    ) async throws {
        isProcessing = true
        lastTurnStats = nil
        currentToolName = nil

        // Ensure isProcessing is always reset, even if ensureProcess() throws
        defer {
            isProcessing = false
            currentOnLine = nil
            stopChecklistPolling()
        }

        // Store callback for the stdout handler
        currentOnLine = onLine

        // Open log file in workspace
        if logHandle == nil, let cwd = workingDirectory {
            let logURL = cwd.appendingPathComponent("log.jsonl")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            logHandle = try? FileHandle(forWritingTo: logURL)
            logHandle?.seekToEndOfFile()
        }

        // Capture credentials fresh each send (token may refresh)
        let authToken = AppState.shared.client.authToken
        let apiURL = AppEnvironment.apiBaseURL
        let keys = Self.readAPIKeys()

        // Start process if needed
        try ensureProcess(
            cliPath: cliPath,
            cwd: workingDirectory,
            authToken: authToken,
            apiURL: apiURL,
            extraEnv: keys
        )

        // Start polling checklist.md for progress
        if let cwd = workingDirectory {
            startChecklistPolling(workspace: cwd)
        }

        // On first message, prepend instructions from workspace MD files
        let actualMessage: String
        if messageCount == 0 {
            let skill = BossSystemPrompt.bootstrap(workspaceURL: workingDirectory, vector: vector)
            actualMessage = """
            <boss-instructions>
            \(skill)
            </boss-instructions>

            Follow the boss-instructions above for this ENTIRE session. Now here is the user's first message:

            \(message)
            """
        } else {
            actualMessage = message
        }

        messageCount += 1

        // Write JSON message to stdin (NDJSON format)
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": actualMessage
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        guard let stdinHandle = stdinPipe?.fileHandleForWriting,
              persistentProcess?.isRunning == true else {
            throw BossError.launchFailed("Claude process is not running")
        }
        stdinHandle.write(data)
        stdinHandle.write(Data([0x0A])) // newline

        // Wait for "result" event from stdout handler
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.responseCompletion = continuation
        }
    }

    /// Start the persistent Claude process if not already running
    private func ensureProcess(
        cliPath: String,
        cwd: URL?,
        authToken: String?,
        apiURL: String?,
        extraEnv: [String: String]
    ) throws {
        // If process is already running, nothing to do
        if let proc = persistentProcess, proc.isRunning {
            return
        }

        // Clean up any dead process state
        cleanupPersistentProcess()

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: cliPath)

        // Build args WITHOUT the message — messages go via stdin
        var args = [
            "--print",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions",
            "--model", claudeModel,
        ]
        if let sid = sessionId {
            args += ["--resume", sid]
        }
        process.arguments = args

        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        if let cwd {
            process.currentDirectoryURL = cwd
        }

        // Environment
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

        // Set up continuous stdout handler
        // readabilityHandler runs on a background thread, so capture raw text
        // and dispatch to MainActor for all property access and parsing.
        stdoutBuffer = ""
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.stdoutBuffer += text
                while let newlineRange = self.stdoutBuffer.range(of: "\n") {
                    let line = String(self.stdoutBuffer[self.stdoutBuffer.startIndex..<newlineRange.lowerBound])
                    self.stdoutBuffer = String(self.stdoutBuffer[newlineRange.upperBound...])

                    guard !line.isEmpty else { continue }

                    if let logData = (line + "\n").data(using: .utf8) {
                        self.logHandle?.write(logData)
                    }

                    self.handleClaudeLine(line)
                }
            }
        }

        // Set up stderr handler
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                if let logData = ("[stderr] " + text + "\n").data(using: .utf8) {
                    self.logHandle?.write(logData)
                }
            }
        }

        // Handle process death
        process.terminationHandler = { proc in
            BossPIDFile.remove(proc.processIdentifier)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.persistentProcess = nil
                self.stdinPipe = nil
                self.stdoutPipe = nil
                self.stderrPipe = nil
                // If we were mid-response, signal error
                if let completion = self.responseCompletion {
                    let status = proc.terminationStatus
                    if status == 0 || status == -15 /* SIGTERM from stop() */ {
                        completion.resume()
                    } else {
                        completion.resume(throwing: BossError.exitCode(Int(status), "Claude process terminated unexpectedly"))
                    }
                    self.responseCompletion = nil
                    self.isProcessing = false
                    self.currentOnLine = nil
                }
            }
        }

        // Store references
        persistentProcess = process
        stdinPipe = stdin
        stdoutPipe = stdout
        stderrPipe = stderr

        // Launch
        do {
            try process.run()
            BossPIDFile.add(process.processIdentifier)
        } catch {
            cleanupPersistentProcess()
            throw BossError.launchFailed(error.localizedDescription)
        }
    }

    /// Parse a single NDJSON line from Claude's stdout.
    ///
    /// Claude CLI `--output-format stream-json` emits full message objects per line:
    ///   - `{"type": "assistant", "message": {"content": [...]}}` — text + tool_use blocks
    ///   - `{"type": "user", "message": {"content": [...]}}` — tool results
    ///   - `{"type": "result", "result": "..."}` — end of turn summary
    ///
    /// Only forwards text to the chat via two paths:
    /// 1. `apex_chat` tool calls — agent intentionally sends a message to the user
    /// 2. `result` events — final summary at end of turn (fallback)
    ///
    /// Regular text blocks are suppressed to keep working notes out of the chat.
    private func handleClaudeLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // Capture session_id from any event that carries one
        if let sid = json["session_id"] as? String {
            Task { @MainActor in
                self.sessionId = sid
                self.persistSessionId(sid)
            }
        }

        let type = json["type"] as? String

        if type == "assistant" {
            // Full assistant message — scan content blocks for apex_chat tool calls
            guard let msg = json["message"] as? [String: Any],
                  let content = msg["content"] as? [[String: Any]]
            else { return }

            // Capture the last tool_use name for activity display
            for block in content {
                if block["type"] as? String == "tool_use",
                   let name = block["name"] as? String {
                    self.currentToolName = name
                }
            }

            for block in content {
                guard block["type"] as? String == "tool_use",
                      block["name"] as? String == "mcp__apex-tools__apex_chat",
                      let input = block["input"] as? [String: Any],
                      let message = input["message"] as? String,
                      !message.isEmpty
                else { continue }

                self.currentOnLine?(message)
            }
            // Text blocks are intentionally not forwarded

        } else if type == "user" {
            // Tool results coming back — agent is thinking, clear tool name
            self.currentToolName = nil

        } else if type == "result" {
            // Result is always a conversational summary — forward as fallback
            if let result = json["result"] as? String, !result.isEmpty {
                self.currentOnLine?(result)
            }
            // Clear tool name and parse turn stats
            self.currentToolName = nil
            self.parseTurnStats(from: json)
            // Write stats.json to workspace for dev visibility
            self.writeStats(from: json)
            // Turn complete — resume the waiting send()
            self.responseCompletion?.resume()
            self.responseCompletion = nil
        }
    }

    /// Write token usage and cost stats to `stats.json` in the workspace directory.
    /// Called once per turn when the `result` event arrives.
    private func writeStats(from resultJson: [String: Any]) {
        guard let wsURL = workspaceURL else { return }

        let durationMs = resultJson["duration_ms"] as? Int ?? 0
        let numTurns = resultJson["num_turns"] as? Int ?? 0
        let totalCost = resultJson["total_cost_usd"] as? Double ?? 0

        // Per-model breakdown
        let modelUsage = resultJson["modelUsage"] as? [String: Any] ?? [:]

        // Aggregated usage
        let usage = resultJson["usage"] as? [String: Any] ?? [:]
        let inputTokens = usage["input_tokens"] as? Int ?? 0
        let outputTokens = usage["output_tokens"] as? Int ?? 0
        let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
        let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0

        // Build per-model stats
        var models: [[String: Any]] = []
        for (name, data) in modelUsage {
            guard let m = data as? [String: Any] else { continue }
            models.append([
                "model": name,
                "input_tokens": m["inputTokens"] as? Int ?? 0,
                "output_tokens": m["outputTokens"] as? Int ?? 0,
                "cache_read_tokens": m["cacheReadInputTokens"] as? Int ?? 0,
                "cache_create_tokens": m["cacheCreationInputTokens"] as? Int ?? 0,
                "cost_usd": m["costUSD"] as? Double ?? 0,
            ])
        }

        let stats: [String: Any] = [
            "agent": agent.rawValue,
            "duration_s": Double(durationMs) / 1000.0,
            "turns": numTurns,
            "total_cost_usd": totalCost,
            "input_tokens": inputTokens,
            "output_tokens": outputTokens,
            "cache_read_tokens": cacheRead,
            "cache_create_tokens": cacheCreate,
            "models": models,
        ]

        if let data = try? JSONSerialization.data(withJSONObject: stats, options: [.prettyPrinted, .sortedKeys]) {
            let url = wsURL.appendingPathComponent("stats.json")
            try? data.write(to: url)
        }
    }

    /// Parse turn stats from a `result` event into `lastTurnStats`.
    private func parseTurnStats(from json: [String: Any]) {
        let durationMs = json["duration_ms"] as? Int ?? 0
        let numTurns = json["num_turns"] as? Int ?? 0
        let totalCost = json["total_cost_usd"] as? Double ?? 0

        let usage = json["usage"] as? [String: Any] ?? [:]
        let inputTokens = usage["input_tokens"] as? Int ?? 0
        let outputTokens = usage["output_tokens"] as? Int ?? 0

        lastTurnStats = TurnStats(
            durationSeconds: Double(durationMs) / 1000.0,
            totalCostUSD: totalCost,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            numTurns: numTurns
        )
    }

    /// Clean up persistent process state without terminating
    func cleanupPersistentProcess() {
        persistentProcess = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutBuffer = ""
    }

}
