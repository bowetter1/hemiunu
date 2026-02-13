import Foundation

extension LocalWorkspaceService {
    // MARK: - File Operations

    /// Read a file from a local project
    func readFile(project: String, path: String) throws -> String {
        let filePath = try validatedPath(project: project, path: path)
        return try String(contentsOf: filePath, encoding: .utf8)
    }

    /// Write a file to a local project
    func writeFile(project: String, path: String, content: String) throws {
        let filePath = try validatedPath(project: project, path: path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Write binary data to a local project
    func writeBinary(project: String, path: String, data: Data) throws {
        let filePath = try validatedPath(project: project, path: path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: filePath)
    }

    /// Delete a file from a local project
    func deleteFile(project: String, path: String) throws {
        let filePath = try validatedPath(project: project, path: path)
        try FileManager.default.removeItem(at: filePath)
    }

    /// List files in a project directory (recursive)
    func listFiles(project: String, directory: String = "") -> [LocalFileInfo] {
        let dir: URL
        if directory.isEmpty {
            dir = projectPath(project)
        } else {
            guard let validated = try? validatedPath(project: project, path: directory) else { return [] }
            dir = validated
        }

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

    // MARK: - Fork

    /// Duplicate a version directory to the next available version number
    func forkVersion(sourceProject: String) throws -> String {
        let components = sourceProject.components(separatedBy: "/")
        guard components.count == 2 else { throw NSError(domain: "Forge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid project format"]) }
        let parentName = components[0]
        let parentDir = rootDirectory.appendingPathComponent(parentName)
        let fm = FileManager.default

        // Find max existing version number
        let siblings = (try? fm.contentsOfDirectory(atPath: parentDir.path)) ?? []
        let maxVersion = siblings.compactMap { dir -> Int? in
            guard dir.hasPrefix("v"), let num = Int(dir.dropFirst()) else { return nil }
            return num
        }.max() ?? 0

        let newVersion = "v\(maxVersion + 1)"
        let newProject = "\(parentName)/\(newVersion)"
        let sourceURL = projectPath(sourceProject)
        let destURL = parentDir.appendingPathComponent(newVersion)

        try fm.copyItem(at: sourceURL, to: destURL)

        // Read original agent name and write fork label
        let agentFile = destURL.appendingPathComponent("agent-name.txt")
        let originalName = (try? String(contentsOf: sourceURL.appendingPathComponent("agent-name.txt"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let forkName = originalName.map { "Fork av \($0)" } ?? "Fork"
        try forkName.write(to: agentFile, atomically: true, encoding: .utf8)

        // Remove .git from the copy
        let gitDir = destURL.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            try? fm.removeItem(at: gitDir)
        }

        return newProject
    }
}
