import Foundation

/// Extracts HTML from AI responses and writes it to the workspace
struct ContentExtractor {

    /// Extract HTML content from a ```html code block
    func extractHTML(from content: String) -> String? {
        let pattern = "```html\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            let fallbackPattern = "```\\s*\\n(<!DOCTYPE[\\s\\S]*?)\\n```"
            if let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [.caseInsensitive]),
               let fallbackMatch = fallbackRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let fallbackRange = Range(fallbackMatch.range(at: 1), in: content) {
                return String(content[fallbackRange])
            }
            return nil
        }
        return String(content[range])
    }

    /// Remove all ``` code blocks from a string, keeping surrounding text
    func stripCodeBlocks(from content: String) -> String {
        let pattern = "```[\\w]*\\s*\\n[\\s\\S]*?\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
    }

    /// Extract HTML, write to workspace, return display text or nil if no HTML found
    @MainActor func processAndSave(content: String, workspace: LocalWorkspaceService,
                                   projectName: String) throws -> String? {
        guard let html = extractHTML(from: content) else { return nil }

        try workspace.writeFile(project: projectName, path: "index.html", content: html)

        let chatText = stripCodeBlocks(from: content).trimmingCharacters(in: .whitespacesAndNewlines)
        return chatText.isEmpty
            ? "Site updated."
            : chatText + "\n\n\u{2705} Site updated."
    }
}
