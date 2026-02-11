import Foundation

/// Loads prompt templates from ~/Forge/prompts/*.md at runtime.
///
/// No fallbacks — if a file is missing, you get an empty string and it's immediately obvious.
/// Files are re-read on every access (no caching) so edits take effect immediately.
enum PromptLoader {
    private static let promptsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Forge/prompts")

    /// Load boss.md — orchestrator prompt
    static var boss: String { load("boss.md") }

    /// Load builder.md — builder agent prompt
    static var builder: String { load("builder.md") }

    /// Load reviewer.md — code review agent prompt
    static var reviewer: String { load("reviewer.md") }

    /// Load tester.md — visual QA agent prompt
    static var tester: String { load("tester.md") }

    // MARK: - Private

    private static func load(_ filename: String) -> String {
        let url = promptsDir.appendingPathComponent(filename)
        guard let content = try? String(contentsOf: url, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[PromptLoader] ⚠️ MISSING: ~/Forge/prompts/\(filename)")
            return ""
        }
        return content
    }
}
