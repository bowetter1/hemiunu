import Foundation

extension ToolExecutor {
    // MARK: - File Tools

    func executeListFiles() -> String {
        let files = workspace.listFiles(project: projectName)
        if files.isEmpty {
            return "Project is empty — no files found."
        }

        let listing = files.map { file in
            let sizeStr = file.isDirectory ? "dir" : formatSize(file.size)
            return "\(file.path) (\(sizeStr))"
        }.joined(separator: "\n")

        return listing
    }

    func executeReadFile(path: String) throws -> String {
        try workspace.readFile(project: projectName, path: path)
    }

    func executeCreateFile(path: String, content: String) throws -> String {
        try workspace.writeFile(project: projectName, path: path, content: content)
        onFileWrite?()
        return "Created \(path) (\(content.count) chars)"
    }

    func executeEditFile(path: String, search: String, replace: String) throws -> String {
        let content = try workspace.readFile(project: projectName, path: path)
        guard content.contains(search) else {
            throw ToolError.searchStringNotFound(path: path, search: String(search.prefix(80)))
        }

        let updated = content.replacingOccurrences(of: search, with: replace)
        try workspace.writeFile(project: projectName, path: path, content: updated)
        onFileWrite?()

        let snippet = contextSnippet(content: updated, around: replace)
        return "Edited \(path) — replaced \(search.count) chars with \(replace.count) chars\n\n\(snippet)"
    }

    /// Extract a few lines around the replaced text so the LLM can verify without a full read_file.
    func contextSnippet(content: String, around target: String, contextLines: Int = 2) -> String {
        guard let range = content.range(of: target) else { return "" }

        let lines = content.components(separatedBy: "\n")
        let prefix = content[content.startIndex..<range.lowerBound]
        let targetLine = prefix.components(separatedBy: "\n").count - 1
        let start = max(0, targetLine - contextLines)
        let end = min(lines.count - 1, targetLine + target.components(separatedBy: "\n").count - 1 + contextLines)
        let slice = lines[start...end].enumerated().map { (i, line) in
            let lineNum = start + i + 1
            return String(format: "%4d│ %@", lineNum, String(line.prefix(120)))
        }

        return slice.joined(separator: "\n")
    }

    func executeRunCommand(command: String) async throws -> String {
        let result = try await workspace.exec(
            command,
            cwd: workspace.projectPath(projectName),
            timeout: 120
        )

        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = output.count > 5000 ? String(output.suffix(5000)) : output
        if result.succeeded {
            return truncated.isEmpty ? "Command completed successfully (no output)" : truncated
        } else {
            return "Exit code \(result.exitCode)\n\(truncated)"
        }
    }

    func executeDeleteFile(path: String) throws -> String {
        try workspace.deleteFile(project: projectName, path: path)
        return "Deleted \(path)"
    }
}
