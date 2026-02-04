import Foundation
import Observation

/// Non-singleton boss service that runs any AI agent CLI.
/// Each instance owns its own Process, session, and log — parallel by design.
///
/// For Claude: uses a **persistent long-lived process** with `--input-format stream-json`
/// so multiple messages are sent via stdin without process restart overhead.
/// For other agents: spawns a new process per message (unchanged).
@MainActor
@Observable
class BossService {
    let id: String
    let agent: AIAgent
    var claudeModel: String = "opus"

    // MARK: - State

    private(set) var isProcessing = false
    private var messageCount = 0
    private var sessionId: String?
    /// Tracks whether we're inside a fenced code block (```...```) to filter from chat
    private var insideCodeFence = false

    /// File handle for writing raw agent output to workspace log
    private var logHandle: FileHandle?

    /// Workspace directory — set externally so we can persist session IDs
    var workspaceURL: URL?

    // MARK: - Persistent Process State (Claude only)

    /// The long-lived Claude process (reused across messages)
    private var persistentProcess: Process?
    /// Pipe to write NDJSON messages into Claude's stdin
    private var stdinPipe: Pipe?
    /// Pipe to read streaming JSON responses from Claude's stdout
    private var stdoutPipe: Pipe?
    /// Pipe to read error output from Claude's stderr
    private var stderrPipe: Pipe?
    /// Continuation that `send()` awaits — resumed when a "result" event arrives
    private var responseCompletion: CheckedContinuation<Void, Error>?
    /// Callback for the current in-flight message's stdout lines
    private var currentOnLine: ((String) -> Void)?
    /// Buffer for partial lines from stdout (data may arrive in chunks not aligned to newlines)
    private var stdoutBuffer = ""

    // MARK: - Non-Claude per-process state

    private var runningProcess: Process?
    /// Timer that polls chat.jsonl for new messages from non-Claude agents
    private var chatPollTimer: Timer?
    /// Byte offset tracking how far we've read in chat.jsonl
    private var chatFileOffset: UInt64 = 0

    init(id: String, agent: AIAgent = .claude) {
        self.id = id
        self.agent = agent
    }

    /// Restore a previously saved session ID from the workspace
    func restoreSession(from workspace: URL) {
        self.workspaceURL = workspace
        let sessionFile = workspace.appendingPathComponent(".claude-session-id")
        if let sid = try? String(contentsOf: sessionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sid.isEmpty {
            self.sessionId = sid
            self.messageCount = 1  // Ensure --resume is used
        }
    }

    // MARK: - Availability

    static func cliPath(for agent: AIAgent) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch agent {
        case .claude: return "\(home)/.local/bin/claude"
        case .gemini: return "/opt/homebrew/bin/gemini"
        case .kimi:   return "\(home)/.local/bin/kimi"
        case .codex:  return "/opt/homebrew/bin/codex"
        }
    }

    static func isAvailable(agent: AIAgent) -> Bool {
        FileManager.default.fileExists(atPath: cliPath(for: agent))
    }

    /// Legacy convenience — checks Claude availability
    static var isAvailable: Bool {
        isAvailable(agent: .claude)
    }

    // MARK: - Actions

    /// Send a message to the agent, streaming output line by line
    func send(
        message: String,
        workingDirectory: URL?,
        vector: String? = nil,
        onLine: @escaping (String) -> Void
    ) async throws {
        guard !isProcessing else { return }

        // Track workspace for session persistence
        if let cwd = workingDirectory {
            workspaceURL = cwd
        }

        let cliPath = Self.cliPath(for: agent)
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw BossError.notInstalled(agent)
        }

        // Claude uses persistent process with stream-json stdin
        if agent == .claude {
            try await sendClaude(
                message: message,
                cliPath: cliPath,
                workingDirectory: workingDirectory,
                vector: vector,
                onLine: onLine
            )
        } else {
            try await sendOtherAgent(
                message: message,
                cliPath: cliPath,
                workingDirectory: workingDirectory,
                vector: vector,
                onLine: onLine
            )
        }
    }

    // MARK: - Claude Persistent Process

    /// Send a message to Claude via the persistent stream-json process
    private func sendClaude(
        message: String,
        cliPath: String,
        workingDirectory: URL?,
        vector: String?,
        onLine: @escaping (String) -> Void
    ) async throws {
        isProcessing = true

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
        stdinPipe?.fileHandleForWriting.write(data)
        stdinPipe?.fileHandleForWriting.write("\n".data(using: .utf8)!)

        // Wait for "result" event from stdout handler
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.responseCompletion = continuation
            }
        } catch {
            isProcessing = false
            currentOnLine = nil
            throw error
        }

        isProcessing = false
        currentOnLine = nil
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
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
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
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
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
        } else if type == "result" {
            // Result is always a conversational summary — forward as fallback
            if let result = json["result"] as? String, !result.isEmpty {
                self.currentOnLine?(result)
            }
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

    /// Clean up persistent process state without terminating
    private func cleanupPersistentProcess() {
        persistentProcess = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutBuffer = ""
    }

    // MARK: - chat.jsonl Polling (non-Claude agents)

    /// Start polling `chat.jsonl` in the workspace for new messages written by the agent's MCP tool.
    private func startChatFilePolling(workspace: URL, onLine: @escaping (String) -> Void) {
        let chatURL = workspace.appendingPathComponent("chat.jsonl")

        // Truncate any leftover file from a previous run so we only see fresh messages
        try? "".write(to: chatURL, atomically: true, encoding: .utf8)
        chatFileOffset = 0

        chatPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pollChatFile(chatURL: chatURL, onLine: onLine)
            }
        }
    }

    /// Read new lines from chat.jsonl starting at the current offset.
    private func pollChatFile(chatURL: URL, onLine: @escaping (String) -> Void) {
        guard FileManager.default.fileExists(atPath: chatURL.path) else { return }
        guard let handle = try? FileHandle(forReadingFrom: chatURL) else { return }
        defer { try? handle.close() }

        handle.seek(toFileOffset: chatFileOffset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }
        chatFileOffset += UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Parse JSON line to extract the message content
            if let lineData = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
               let content = json["content"] as? String,
               !content.isEmpty {
                onLine(content)
            }
        }
    }

    /// Stop the chat.jsonl poll timer.
    private func stopChatFilePolling() {
        chatPollTimer?.invalidate()
        chatPollTimer = nil
        chatFileOffset = 0
    }

    // MARK: - Non-Claude Agents

    /// Send a message to a non-Claude agent using the existing per-process approach.
    /// Chat messages come exclusively from `chat.jsonl` (written by the agent's `apex_chat` MCP tool).
    /// Stdout is logged to `log.jsonl` but NOT forwarded to the chat.
    private func sendOtherAgent(
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
        defer {
            isProcessing = false
            runningProcess = nil
            stopChatFilePolling()
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
                guard let self else { return }
                if let logData = (line + "\n").data(using: .utf8) {
                    self.logHandle?.write(logData)
                }
            },
            onStderr: { [weak self] text in
                guard let self else { return }
                if let logData = ("[stderr] " + text + "\n").data(using: .utf8) {
                    self.logHandle?.write(logData)
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
    private func persistSessionId(_ sid: String) {
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
        runningProcess?.terminate()
        runningProcess = nil
        isProcessing = false
    }

    /// Reset the conversation — next message starts a fresh session
    func reset() {
        stop()
        messageCount = 0
        sessionId = nil
        insideCodeFence = false
        stopChatFilePolling()
        // Close and release log handle
        try? logHandle?.close()
        logHandle = nil
    }

    // MARK: - Agent-Aware CLI Args (non-Claude only)

    private func buildAgentArgs(message: String) -> [String] {
        switch agent {
        case .claude:
            // Claude uses persistent process — this should not be called
            return []

        case .gemini:
            return [message, "--sandbox", "false", "--yolo"]

        case .kimi:
            return ["--print", "--prompt", message, "--mcp-config-file", ".mcp.json"]

        case .codex:
            return ["exec", message, "--full-auto"]
        }
    }

    // MARK: - Output Filter

    /// Strip markdown code fences from text. For Claude, tool_use content is
    /// already filtered at the JSON level — this only handles ``` blocks
    /// that appear inside conversational text.
    private func stripCodeFences(_ text: String) -> String {
        var result = ""
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                insideCodeFence.toggle()
                continue
            }
            if insideCodeFence { continue }
            result += result.isEmpty ? line : "\n" + line
        }
        return result
    }

    // MARK: - Streaming Process Execution (non-Claude agents)

    private func streamExec(
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

                let handle = stdout.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines)
                        for line in lines where !line.isEmpty {
                            onLine(line)
                        }
                    }
                }

                // Collect stderr for error reporting and optional logging
                var stderrChunks: [String] = []
                let errHandle = stderr.fileHandleForReading
                errHandle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        stderrChunks.append(text)
                        onStderr?(text)
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: BossError.launchFailed(error.localizedDescription))
                    return
                }

                // Poll for process exit OR done.signal from the agent
                let doneSignalPath = cwd?.appendingPathComponent("done.signal").path
                while process.isRunning {
                    if let path = doneSignalPath,
                       FileManager.default.fileExists(atPath: path) {
                        process.terminate()
                        process.waitUntilExit()
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.5)
                }

                handle.readabilityHandler = nil
                errHandle.readabilityHandler = nil

                let status = process.terminationStatus
                // Exit 0 = normal, -15 = SIGTERM from stop()/done.signal, 2 = Kimi CLI normal exit
                if status == 0 || status == -15 || status == 2 {
                    continuation.resume()
                } else {
                    let errText = stderrChunks.joined()
                    continuation.resume(throwing: BossError.exitCode(Int(status), errText.isEmpty ? "Process exited with code \(status)" : errText))
                }
            }
        }
    }

    // MARK: - API Keys

    static func readAPIKeys() -> [String: String] {
        let keyFiles: [(envName: String, fileName: String)] = [
            ("ANTHROPIC_API_KEY", "anthropic_key"),
            ("DAYTONA_API_KEY", "daytona_key"),
            ("PEXELS_API_KEY", "pexels_key"),
            ("OPENAI_API_KEY", "openai_key"),
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var result: [String: String] = [:]

        for (envName, fileName) in keyFiles {
            if let value = ProcessInfo.processInfo.environment[envName], !value.isEmpty {
                result[envName] = value
                continue
            }
            let path = "\(home)/.apex/\(fileName)"
            if let value = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                result[envName] = value
            }
        }
        return result
    }
}

// MARK: - Errors

enum BossError: LocalizedError {
    case notInstalled(AIAgent)
    case launchFailed(String)
    case exitCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let agent):
            return "\(agent.rawValue) CLI is not installed"
        case .launchFailed(let msg):
            return "Failed to launch boss: \(msg)"
        case .exitCode(let code, let msg):
            return "Boss exited with code \(code): \(msg)"
        }
    }
}
