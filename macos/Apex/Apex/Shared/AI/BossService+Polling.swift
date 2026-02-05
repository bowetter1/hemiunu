import Foundation

extension BossService {
    // MARK: - chat.jsonl Polling (non-Claude agents)

    /// Start polling `chat.jsonl` in the workspace for new messages written by the agent's MCP tool.
    func startChatFilePolling(workspace: URL, onLine: @escaping (String) -> Void) {
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
    /// Only advances the offset to the last complete line (last `\n`), so
    /// incomplete trailing data is re-read on the next poll — preventing
    /// message loss from partial writes.
    func pollChatFile(chatURL: URL, onLine: @escaping (String) -> Void) {
        guard FileManager.default.fileExists(atPath: chatURL.path) else { return }
        guard let handle = try? FileHandle(forReadingFrom: chatURL) else { return }
        defer { try? handle.close() }

        handle.seek(toFileOffset: chatFileOffset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }

        guard let text = String(data: data, encoding: .utf8) else { return }

        // Only advance offset to last newline — incomplete trailing line re-read next poll
        if let lastNewline = text.lastIndex(of: "\n") {
            let completeText = String(text[...lastNewline])
            let completeBytes = completeText.utf8.count
            chatFileOffset += UInt64(completeBytes)

            for line in completeText.components(separatedBy: "\n") {
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
        // else: don't advance — entire chunk is one incomplete line, retry next poll
    }

    /// Stop the chat.jsonl poll timer.
    func stopChatFilePolling() {
        chatPollTimer?.invalidate()
        chatPollTimer = nil
        chatFileOffset = 0
    }

}
