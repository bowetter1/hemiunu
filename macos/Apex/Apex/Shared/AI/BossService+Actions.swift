import Foundation

extension BossService {
    // MARK: - Actions

    /// Send a message to the agent, streaming output line by line
    func send(
        message: String,
        workingDirectory: URL?,
        vector: String? = nil,
        onLine: @escaping (String) -> Void
    ) async throws {
        guard !isProcessing else { throw BossError.alreadyProcessing }

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

}
