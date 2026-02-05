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

    var isProcessing = false
    var messageCount = 0
    var sessionId: String?
    /// Tracks whether we're inside a fenced code block (```...```) to filter from chat
    var insideCodeFence = false

    // MARK: - Activity State

    /// The raw name of the tool currently being executed (nil when agent is thinking)
    var currentToolName: String?
    /// Live checklist progress parsed from checklist.md
    var checklistProgress: ChecklistProgress?
    /// Stats from the most recent completed turn
    var lastTurnStats: TurnStats?
    /// Timer that polls checklist.md for progress updates
    var checklistPollTimer: Timer?

    /// File handle for writing raw agent output to workspace log
    var logHandle: FileHandle?

    /// Workspace directory — set externally so we can persist session IDs
    var workspaceURL: URL?

    // MARK: - Persistent Process State (Claude only)

    /// The long-lived Claude process (reused across messages)
    var persistentProcess: Process?
    /// Pipe to write NDJSON messages into Claude's stdin
    var stdinPipe: Pipe?
    /// Pipe to read streaming JSON responses from Claude's stdout
    var stdoutPipe: Pipe?
    /// Pipe to read error output from Claude's stderr
    var stderrPipe: Pipe?
    /// Continuation that `send()` awaits — resumed when a "result" event arrives
    var responseCompletion: CheckedContinuation<Void, Error>?
    /// Callback for the current in-flight message's stdout lines
    var currentOnLine: ((String) -> Void)?
    /// Buffer for partial lines from stdout (data may arrive in chunks not aligned to newlines)
    var stdoutBuffer = ""

    // MARK: - Non-Claude per-process state

    var runningProcess: Process?
    /// Timer that polls chat.jsonl for new messages from non-Claude agents
    var chatPollTimer: Timer?
    /// Byte offset tracking how far we've read in chat.jsonl
    var chatFileOffset: UInt64 = 0

    init(id: String, agent: AIAgent = .claude) {
        self.id = id
        self.agent = agent
    }

    deinit {
        // deinit is nonisolated, but for @MainActor classes deallocation occurs
        // on the main thread. Use assumeIsolated to access actor-isolated state.
        MainActor.assumeIsolated {
            persistentProcess?.terminate()
            persistentProcess = nil
            stdinPipe = nil
            stdoutPipe = nil
            stderrPipe = nil

            runningProcess?.terminate()
            runningProcess = nil

            chatPollTimer?.invalidate()
            chatPollTimer = nil

            checklistPollTimer?.invalidate()
            checklistPollTimer = nil

            try? logHandle?.close()
            logHandle = nil
        }
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

}
