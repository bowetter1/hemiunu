import Foundation

extension LocalWorkspaceService {
    // MARK: - Local Preview Server

    /// Start a local HTTP server for previewing project files
    func startLocalServer(project: String, port: Int = 8421) async throws -> Int {
        stopLocalServer()

        let projectDir = projectPath(project)
        guard FileManager.default.fileExists(atPath: projectDir.path) else {
            throw WorkspaceError.invalidURL
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "http.server", "\(port)", "--bind", "127.0.0.1"]
        process.currentDirectoryURL = projectDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        serverProcess = process
        serverPort = port

        try await Task.sleep(nanoseconds: 500_000_000)
        return port
    }

    /// Stop the local preview server
    func stopLocalServer() {
        serverProcess?.terminate()
        serverProcess = nil
        serverPort = nil
    }

    /// List workspace directories that contain HTML files
    func listHTMLWorkspaces() -> [LocalProject] {
        let fm = FileManager.default
        var workspaces: [LocalProject] = []

        guard let topDirs = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for dir in topDirs {
            guard let values = try? dir.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else { continue }

            let topName = dir.lastPathComponent

            if findMainHTML(project: topName) != nil {
                workspaces.append(LocalProject(
                    name: topName,
                    path: dir,
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    hasPackageJson: fm.fileExists(atPath: dir.appendingPathComponent("package.json").path),
                    hasGit: fm.fileExists(atPath: dir.appendingPathComponent(".git").path),
                    hasDockerfile: fm.fileExists(atPath: dir.appendingPathComponent("Dockerfile").path),
                    briefTitle: readBriefTitle(at: dir)
                ))
            }

            // Check subdirectories
            guard let subDirs = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for sub in subDirs {
                guard let subValues = try? sub.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                      subValues.isDirectory == true else { continue }

                let relativeName = "\(topName)/\(sub.lastPathComponent)"
                guard findMainHTML(project: relativeName) != nil else { continue }

                let agentName = try? String(
                    contentsOf: sub.appendingPathComponent("agent-name.txt"),
                    encoding: .utf8
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                workspaces.append(LocalProject(
                    name: relativeName,
                    path: sub,
                    modifiedAt: subValues.contentModificationDate ?? .distantPast,
                    hasPackageJson: fm.fileExists(atPath: sub.appendingPathComponent("package.json").path),
                    hasGit: fm.fileExists(atPath: sub.appendingPathComponent(".git").path),
                    hasDockerfile: fm.fileExists(atPath: sub.appendingPathComponent("Dockerfile").path),
                    briefTitle: readBriefTitle(at: sub),
                    agentName: agentName
                ))
            }
        }

        return workspaces.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Read project name from project-name.txt or brief.md
    private func readBriefTitle(at url: URL) -> String? {
        let nameFile = url.appendingPathComponent("project-name.txt")
        if let name = try? String(contentsOf: nameFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        let parentNameFile = url.deletingLastPathComponent().appendingPathComponent("project-name.txt")
        if let name = try? String(contentsOf: parentNameFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        let briefURL = url.appendingPathComponent("brief.md")
        guard let content = try? String(contentsOf: briefURL, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)

        // Strategy 1: Find "## Project" heading → take first non-empty line after it
        var foundProject = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("## project") {
                foundProject = true
                continue
            }
            if foundProject && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return cleanTitle(trimmed)
            }
        }

        // Strategy 2: Use the first "# Heading" as the title
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.lowercased() != "brief" {
                    return cleanTitle(title)
                }
            }
        }

        // Strategy 3: First non-empty, non-heading line (last resort)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("---") {
                return cleanTitle(trimmed)
            }
        }

        return nil
    }

    /// Truncate and clean a title string for sidebar display
    private func cleanTitle(_ raw: String) -> String? {
        let clean = raw
            .components(separatedBy: "—").first?
            .components(separatedBy: ".").first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        guard !clean.isEmpty else { return nil }
        return clean.count > 35 ? String(clean.prefix(32)) + "..." : clean
    }

    /// Find the main HTML file in a project
    func findMainHTML(project: String) -> String? {
        let dir = projectPath(project)
        let candidates = [
            "index.html",
            "proposal/index.html",
            "dist/index.html",
            "build/index.html",
            "public/index.html",
            "out/index.html",
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
                return candidate
            }
        }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.first { $0.hasSuffix(".html") }
    }

    /// Read HTML content from a local project's main file
    func readMainHTML(project: String) -> String? {
        guard let htmlFile = findMainHTML(project: project) else { return nil }
        let filePath = projectPath(project).appendingPathComponent(htmlFile)
        return try? String(contentsOf: filePath, encoding: .utf8)
    }

    /// Load pages from a local project's HTML files
    func loadPages(project: String) -> [Page] {
        let files = listFiles(project: project)
        let base = projectPath(project)

        return files.compactMap { file in
            guard !file.isDirectory, file.path.hasSuffix(".html") else { return nil }
            if !file.path.contains("/"), file.path != "index.html" { return nil }
            guard let html = try? String(contentsOf: base.appendingPathComponent(file.path), encoding: .utf8) else { return nil }
            return Page.local(
                id: "local-page-\(project)/\(file.path)",
                name: file.name,
                html: html
            )
        }
    }
}
