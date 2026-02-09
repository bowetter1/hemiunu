import Foundation

/// Appends AI request metrics to an ai-log.md markdown table
struct RequestLogger {
    let logDirectory: URL

    func log(provider: AIProvider, projectId: String?, prompt: String,
             totalTime: Double, ttft: Double, chunks: Int, chars: Int,
             inputTokens: Int = 0, outputTokens: Int = 0) {
        let logURL = logDirectory.appendingPathComponent("ai-log.md")
        let dateStr = ISO8601DateFormatter().string(from: Date())
        let projectName = (projectId ?? "none").replacingOccurrences(of: "local:", with: "")
        let promptPreview = String(prompt.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        let tokensStr = inputTokens + outputTokens > 0
            ? "\(inputTokens)→\(outputTokens)"
            : "-"
        let costStr: String
        if inputTokens + outputTokens > 0 {
            let cost = (Double(inputTokens) * provider.inputCostPerMillion + Double(outputTokens) * provider.outputCostPerMillion) / 1_000_000
            costStr = String(format: "$%.2f", cost)
        } else {
            costStr = "-"
        }

        let entry = """
        | \(dateStr) | \(provider.shortLabel) | \(provider.modelName) | \(projectName) | \(promptPreview) | \(String(format: "%.1f", ttft))s | \(String(format: "%.1f", totalTime))s | \(chunks) | \(chars) | \(tokensStr) | \(costStr) |

        """

        // Create file with header if it doesn't exist
        if !FileManager.default.fileExists(atPath: logURL.path) {
            let header = """
            # Forge AI Log

            | Timestamp | Provider | Model | Project | Prompt | TTFT | Total | Chunks | Chars | Tokens | Cost |
            |-----------|----------|-------|---------|--------|------|-------|--------|-------|--------|------|

            """
            try? header.write(to: logURL, atomically: true, encoding: .utf8)
        }

        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
}
