import Foundation

extension BossService {
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

}
