import Foundation

extension LocalWorkspaceService {
    // MARK: - File Operations

    /// Read a file from a local project
    func readFile(project: String, path: String) throws -> String {
        let filePath = projectPath(project).appendingPathComponent(path)
        return try String(contentsOf: filePath, encoding: .utf8)
    }

    /// Write a file to a local project
    func writeFile(project: String, path: String, content: String) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Write binary data to a local project
    func writeBinary(project: String, path: String, data: Data) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: filePath)
    }

    /// Delete a file from a local project
    func deleteFile(project: String, path: String) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        try FileManager.default.removeItem(at: filePath)
    }

    /// List files in a project directory (recursive)
    func listFiles(project: String, directory: String = "") -> [LocalFileInfo] {
        let dir = directory.isEmpty
            ? projectPath(project)
            : projectPath(project).appendingPathComponent(directory)

        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [LocalFileInfo] = []
        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let relativePath = url.path.replacingOccurrences(
                of: projectPath(project).path + "/",
                with: ""
            )
            // Skip node_modules and .next
            if relativePath.hasPrefix("node_modules") || relativePath.hasPrefix(".next") {
                enumerator.skipDescendants()
                continue
            }
            files.append(LocalFileInfo(
                path: relativePath,
                isDirectory: values?.isDirectory ?? false,
                size: values?.fileSize ?? 0
            ))
        }
        return files
    }

}
