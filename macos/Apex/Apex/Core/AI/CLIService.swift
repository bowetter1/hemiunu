import Foundation
import Observation

/// Manages Claude, Gemini, and Codex CLI processes.
/// Spawns CLI subprocesses on the Mac, streams output to UI in real-time.
@MainActor
@Observable
class CLIService {
    static let shared = CLIService()

    // MARK: - State

    var isRunning = false
    var activeAgent: AIAgent?
    var outputLines: [OutputLine] = []
    var error: String?

    private var runningProcess: Process?

    private init() {}

    // MARK: - CLI Paths

    private var cliPaths: [AIAgent: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            .claude: "\(home)/.local/bin/claude",
            .gemini: "/opt/homebrew/bin/gemini",
            .codex: "/opt/homebrew/bin/codex",
            .kimi: "\(home)/.local/bin/kimi",
        ]
    }

    /// Check which CLIs are installed
    func availableAgents() -> [AIAgent] {
        cliPaths.compactMap { agent, path in
            FileManager.default.fileExists(atPath: path) ? agent : nil
        }.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Run Agent

    /// Run a CLI agent with a prompt, streaming output line by line
    func run(
        agent: AIAgent,
        prompt: String,
        workingDirectory: URL? = nil,
        systemPrompt: String? = nil,
        model: String? = nil,
        onLine: ((OutputLine) -> Void)? = nil
    ) async throws {
        guard !isRunning else { throw CLIError.alreadyRunning }
        guard let cliPath = cliPaths[agent],
              FileManager.default.fileExists(atPath: cliPath) else {
            throw CLIError.notInstalled(agent)
        }

        isRunning = true
        activeAgent = agent
        outputLines = []
        error = nil

        defer {
            isRunning = false
            activeAgent = nil
            runningProcess = nil
        }

        let args = buildArgs(agent: agent, prompt: prompt, systemPrompt: systemPrompt, model: model)

        try await streamExec(
            executable: cliPath,
            arguments: args,
            cwd: workingDirectory,
            onLine: { [weak self] line in
                guard let self else { return }
                let outputLine = OutputLine(agent: agent, text: line)
                Task { @MainActor in
                    self.outputLines.append(outputLine)
                    onLine?(outputLine)
                }
            }
        )
    }

    /// Run an AI team: multiple agents sequentially on the same project
    func runTeam(
        tasks: [TeamTask],
        workingDirectory: URL,
        onProgress: ((TeamTask, OutputLine) -> Void)? = nil
    ) async throws -> [TeamResult] {
        var results: [TeamResult] = []

        for task in tasks {
            let startTime = Date()
            outputLines = []

            do {
                try await run(
                    agent: task.agent,
                    prompt: task.prompt,
                    workingDirectory: workingDirectory,
                    systemPrompt: task.systemPrompt,
                    model: task.model,
                    onLine: { line in
                        onProgress?(task, line)
                    }
                )
                results.append(TeamResult(
                    task: task,
                    output: outputLines.map(\.text).joined(separator: "\n"),
                    succeeded: true,
                    duration: Date().timeIntervalSince(startTime)
                ))
            } catch {
                results.append(TeamResult(
                    task: task,
                    output: outputLines.map(\.text).joined(separator: "\n"),
                    succeeded: false,
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                ))
                // Continue with next task even if one fails
            }
        }

        return results
    }

    /// Stop the currently running process
    func stop() {
        runningProcess?.terminate()
        runningProcess = nil
        isRunning = false
        activeAgent = nil
    }

    // MARK: - Build CLI Arguments

    private func buildArgs(agent: AIAgent, prompt: String, systemPrompt: String?, model: String?) -> [String] {
        switch agent {
        case .claude:
            var args = [
                "--print", prompt,
                "--output-format", "text",
                "--dangerously-skip-permissions",
            ]
            if let systemPrompt {
                args += ["--append-system-prompt", systemPrompt]
            }
            if let model {
                args += ["--model", model]
            }
            return args

        case .gemini:
            // Positional query = one-shot mode (non-interactive)
            var args = [prompt, "--sandbox", "false"]
            if let model {
                args += ["--model", model]
            }
            args += ["--yolo"]
            return args

        case .codex:
            var args = ["exec", prompt]
            if let model {
                args += ["--config", "model=\"\(model)\""]
            }
            args += ["--full-auto"]
            return args

        case .kimi:
            var args = ["--print", "--prompt", prompt]
            if let model {
                args += ["--model", model]
            }
            return args
        }
    }

    // MARK: - Streaming Process Execution

    private func streamExec(
        executable: String,
        arguments: [String],
        cwd: URL?,
        onLine: @escaping (String) -> Void
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

                // Environment: inherit user shell + common paths
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
                // Ensure CLIs don't try to use interactive features
                env["TERM"] = "dumb"
                env["NO_COLOR"] = "1"
                process.environment = env

                DispatchQueue.main.async {
                    self?.runningProcess = process
                }

                // Stream stdout line by line
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

                // Also capture stderr
                let errHandle = stderr.fileHandleForReading
                errHandle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines)
                        for line in lines where !line.isEmpty {
                            onLine("[stderr] \(line)")
                        }
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: CLIError.launchFailed(error.localizedDescription))
                    return
                }

                process.waitUntilExit()

                // Clean up handlers
                handle.readabilityHandler = nil
                errHandle.readabilityHandler = nil

                let status = process.terminationStatus
                if status == 0 || status == -15 /* SIGTERM from stop() */ {
                    continuation.resume()
                } else {
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errText = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    Task { @MainActor in
                        self?.error = errText
                    }
                    continuation.resume(throwing: CLIError.exitCode(Int(status), errText))
                }
            }
        }
    }
}

// MARK: - Types

enum AIAgent: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case gemini = "Gemini"
    case codex = "Codex"
    case kimi = "Kimi"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claude: return "brain"
        case .gemini: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .kimi: return "wind"
        }
    }

    var color: String {
        switch self {
        case .claude: return "orange"
        case .gemini: return "blue"
        case .codex: return "green"
        case .kimi: return "purple"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "sonnet"
        case .gemini: return "gemini-2.5-pro"
        case .codex: return "o3"
        case .kimi: return "kimi"
        }
    }

    /// Role in the AI team
    var teamRole: String {
        switch self {
        case .gemini: return "Research & analysis"
        case .claude: return "Code generation & architecture"
        case .codex: return "Code review & optimization"
        case .kimi: return "Code generation & analysis"
        }
    }
}

struct OutputLine: Identifiable {
    let id = UUID()
    let agent: AIAgent
    let text: String
    let timestamp = Date()
}

struct TeamTask: Identifiable {
    let id = UUID()
    let agent: AIAgent
    let prompt: String
    var systemPrompt: String?
    var model: String?
    var label: String?

    var displayLabel: String {
        label ?? "\(agent.rawValue): \(prompt.prefix(50))"
    }
}

struct TeamResult: Identifiable {
    let id = UUID()
    let task: TeamTask
    let output: String
    let succeeded: Bool
    let duration: TimeInterval
    var error: String?
}

enum CLIError: LocalizedError {
    case alreadyRunning
    case notInstalled(AIAgent)
    case launchFailed(String)
    case exitCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "An agent is already running"
        case .notInstalled(let agent):
            return "\(agent.rawValue) CLI is not installed"
        case .launchFailed(let msg):
            return "Failed to launch: \(msg)"
        case .exitCode(let code, let msg):
            return "Exited with code \(code): \(msg)"
        }
    }
}
