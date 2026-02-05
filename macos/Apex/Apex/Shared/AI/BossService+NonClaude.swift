import Foundation

extension BossService {
    // MARK: - Non-Claude Agents

    /// Send a message to a non-Claude agent using the existing per-process approach.
    /// Chat messages come exclusively from `chat.jsonl` (written by the agent's `apex_chat` MCP tool).
    /// Stdout is logged to `log.jsonl` but NOT forwarded to the chat.
    func sendOtherAgent(
        message: String,
        cliPath: String,
        workingDirectory: URL?,
        vector: String?,
        onLine: @escaping (String) -> Void
    ) async throws {
        // Capture credentials fresh each send (token may refresh)
        let authToken = AppState.shared.client.authToken
        let apiURL = AppEnvironment.apiBaseURL
        let keys = Self.readAPIKeys()

        isProcessing = true
        lastTurnStats = nil
        currentToolName = nil
        defer {
            isProcessing = false
            runningProcess = nil
            stopChatFilePolling()
            stopChecklistPolling()
            try? logHandle?.close()
            logHandle = nil
        }

        // Open log file in workspace
        if let cwd = workingDirectory {
            let logURL = cwd.appendingPathComponent("log.jsonl")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            logHandle = try? FileHandle(forWritingTo: logURL)
            logHandle?.seekToEndOfFile()
        }

        // Start polling chat.jsonl BEFORE the process runs
        if let cwd = workingDirectory {
            startChatFilePolling(workspace: cwd, onLine: onLine)
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

        let args = buildAgentArgs(message: actualMessage)
        messageCount += 1

        try await streamExec(
            executable: cliPath,
            arguments: args,
            cwd: workingDirectory,
            authToken: authToken,
            apiURL: apiURL,
            extraEnv: keys,
            onLine: { [weak self] line in
                // Stdout goes to log only — chat messages come from chat.jsonl
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let logData = (line + "\n").data(using: .utf8) {
                        self.logHandle?.write(logData)
                    }
                }
            },
            onStderr: { [weak self] text in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let logData = ("[stderr] " + text + "\n").data(using: .utf8) {
                        self.logHandle?.write(logData)
                    }
                }
            }
        )

        // Final poll to catch any messages written just before process exit
        if let cwd = workingDirectory {
            let chatURL = cwd.appendingPathComponent("chat.jsonl")
            pollChatFile(chatURL: chatURL, onLine: onLine)
        }
    }

    /// Save session ID to workspace so it survives app restarts
    func persistSessionId(_ sid: String) {
        guard agent == .claude else { return }
        guard let wsURL = workspaceURL else { return }
        let sessionFile = wsURL.appendingPathComponent(".claude-session-id")
        try? sid.write(to: sessionFile, atomically: true, encoding: .utf8)
    }

    /// Stop the currently running process
    func stop() {
        // Stop persistent Claude process
        if persistentProcess != nil {
            stdinPipe?.fileHandleForWriting.closeFile()
            persistentProcess?.terminate()
            cleanupPersistentProcess()
            responseCompletion?.resume(throwing: CancellationError())
            responseCompletion = nil
            currentOnLine = nil
            isProcessing = false
        }

        // Stop non-Claude per-process
        stopChatFilePolling()
        stopChecklistPolling()
        runningProcess?.terminate()
        runningProcess = nil
        currentToolName = nil
        isProcessing = false
    }

    /// Reset the conversation — next message starts a fresh session
    func reset() {
        stop()
        messageCount = 0
        sessionId = nil
        insideCodeFence = false
        currentToolName = nil
        checklistProgress = nil
        lastTurnStats = nil
        stopChatFilePolling()
        stopChecklistPolling()
        // Close and release log handle
        try? logHandle?.close()
        logHandle = nil
    }

}
