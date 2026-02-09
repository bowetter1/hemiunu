import Foundation

/// Logs build activity to build-log.md in the project directory — real-time, per-project
@MainActor
class BuildLogger {
    private let workspace: LocalWorkspaceService
    private(set) var projectName: String
    private let startTime: Date
    private var content: String = ""
    private var builderSummaries: [(builder: String, version: Int, success: Bool, input: Int, output: Int, duration: TimeInterval)] = []

    init(workspace: LocalWorkspaceService, projectName: String) {
        self.workspace = workspace
        self.projectName = projectName
        self.startTime = Date()
    }

    func updateProjectName(_ name: String) {
        projectName = name
    }

    // MARK: - Build lifecycle

    func logBuildStart(prompt: String) {
        let dateStr = formatDate(Date())
        content = """
        # Build Log

        **Started:** \(dateStr)
        **Prompt:** \(prompt)

        """
        flush()
    }

    func logPhase(_ title: String) {
        content += """

        ## \(title)
        | Time | Event | Tokens |
        |------|-------|--------|

        """
        flush()
    }

    func logEvent(_ icon: String, _ message: String, tokens: String = "") {
        let t = elapsed()
        content += "| \(t) | \(icon) \(escape(message)) | \(tokens) |\n"
        flush()
    }

    // MARK: - Builder lifecycle

    func logBuilderStart(builder: String, version: Int, direction: String, model: String) {
        content += """

        ### v\(version) — \(builder) (\(model))
        **Direction:** \(direction)

        | Time | Event | Tokens |
        |------|-------|--------|

        """
        flush()
    }

    func logBuilderDone(builder: String, version: Int, success: Bool, inputTokens: Int, outputTokens: Int, duration: TimeInterval) {
        let status = success ? "✅" : "❌"
        content += "\n**Result:** \(status) \(inputTokens)→\(outputTokens) tokens | \(formatDuration(duration))\n\n---\n"
        flush()

        builderSummaries.append((builder, version, success, inputTokens, outputTokens, duration))
    }

    // MARK: - Build complete

    func logBuildDone(totalInput: Int, totalOutput: Int) {
        let totalTime = Date().timeIntervalSince(startTime)
        content += """

        ## Summary

        | Builder | Version | Status | Input | Output | Time |
        |---------|---------|--------|-------|--------|------|

        """
        for s in builderSummaries {
            let status = s.success ? "✅" : "❌"
            content += "| \(s.builder) | v\(s.version) | \(status) | \(s.input) | \(s.output) | \(formatDuration(s.duration)) |\n"
        }
        content += """

        **Total time:** \(formatDuration(totalTime))
        **Total tokens:** \(totalInput)→\(totalOutput) (\(totalInput + totalOutput) total)

        """
        flush()
    }

    // MARK: - Helpers

    private func elapsed() -> String {
        let seconds = Int(Date().timeIntervalSince(startTime))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func flush() {
        guard !projectName.isEmpty else { return }
        try? workspace.writeFile(project: projectName, path: "build-log.md", content: content)
    }
}
