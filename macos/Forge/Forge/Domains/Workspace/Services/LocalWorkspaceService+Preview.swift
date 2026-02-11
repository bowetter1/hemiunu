import Foundation

extension LocalWorkspaceService {
    // MARK: - Local Preview Server

    /// Resolve the best preview URL for a project.
    /// For JS app projects, prefer a local dev server. Otherwise fall back to file-based preview.
    func resolvePreviewURL(project: String) async -> URL {
        if let devURL = await startFrontendPreviewIfPossible(project: project) {
            return devURL
        }
        stopLocalServer()
        return projectPath(project)
    }

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
        activeProcess = nil
        isRunning = false
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
            "frontend/index.html",
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

    // MARK: - Frontend Dev Server

    private func startFrontendPreviewIfPossible(project: String) async -> URL? {
        if activeProcess == "preview:\(project)",
           serverProcess?.isRunning == true,
           let port = serverPort,
           let url = URL(string: "http://127.0.0.1:\(port)") {
            return url
        }

        let root = projectPath(project)
        let candidateDirs = [
            root,
            root.appendingPathComponent("frontend"),
            root.appendingPathComponent("apps/web"),
            root.appendingPathComponent("web"),
        ]

        var selected: (dir: URL, script: (name: String, body: String))?
        for dir in candidateDirs {
            let packageJSON = dir.appendingPathComponent("package.json")
            guard FileManager.default.fileExists(atPath: packageJSON.path) else { continue }
            if let script = selectPreviewScript(at: packageJSON) {
                selected = (dir, script)
                break
            }
        }

        guard let selected else { return nil }

        stopLocalServer()

        // Kill stale dev servers from previous app sessions (async — won't block UI)
        let candidatePorts = [5173, 3000, 4173, 8080]
        for port in candidatePorts {
            _ = try? await exec("lsof -ti :\(port) | xargs kill 2>/dev/null", timeout: 3)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)

        for port in candidatePorts {
            guard let command = buildPreviewCommand(projectDir: selected.dir, script: selected.script, port: port) else { continue }
            do {
                try launchDevServer(command: command.command, env: command.env, cwd: selected.dir, project: project, port: port)
                guard let url = URL(string: "http://127.0.0.1:\(port)") else {
                    stopLocalServer()
                    continue
                }
                // Only accept if OUR process is still running (not a stale server)
                if await waitForServer(url: url, process: serverProcess),
                   serverProcess?.isRunning == true {
                    return url
                }
                stopLocalServer()
            } catch {
                stopLocalServer()
            }
        }

        return nil
    }


    private func launchDevServer(
        command: String,
        env: [String: String],
        cwd: URL,
        project: String,
        port: Int
    ) throws {
        stopLocalServer()

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = cwd
        process.standardOutput = pipe
        process.standardError = pipe

        var environment = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/local/share/npm/bin",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/v20/bin",
        ]
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        for (key, value) in env {
            environment[key] = value
        }
        process.environment = environment

        process.terminationHandler = { [weak self] terminatedProcess in
            guard let self else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                self.lastOutput = output
                if self.serverProcess === terminatedProcess {
                    self.serverProcess = nil
                    self.serverPort = nil
                    self.activeProcess = nil
                    self.isRunning = false
                }
            }
        }

        try process.run()
        serverProcess = process
        serverPort = port
        activeProcess = "preview:\(project)"
        isRunning = true
    }

    private func waitForServer(url: URL, process: Process?, timeout: TimeInterval = 12) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if process?.isRunning != true { return false }
            if await isReachable(url: url) { return true }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
        return false
    }

    private func isReachable(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<500).contains(http.statusCode)
            }
            return true
        } catch {
            return false
        }
    }

    private func selectPreviewScript(at packageJSON: URL) -> (name: String, body: String)? {
        guard let data = try? Data(contentsOf: packageJSON),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = object["scripts"] as? [String: Any] else { return nil }

        if let dev = scripts["dev"] as? String {
            return ("dev", dev)
        }
        if let start = scripts["start"] as? String {
            return ("start", start)
        }
        return nil
    }

    private func buildPreviewCommand(
        projectDir: URL,
        script: (name: String, body: String),
        port: Int
    ) -> (command: String, env: [String: String])? {
        let fm = FileManager.default
        let body = script.body.lowercased()
        let hasBun = fm.fileExists(atPath: projectDir.appendingPathComponent("bun.lock").path)
            || fm.fileExists(atPath: projectDir.appendingPathComponent("bun.lockb").path)
        let hasPnpm = fm.fileExists(atPath: projectDir.appendingPathComponent("pnpm-lock.yaml").path)
        let hasYarn = fm.fileExists(atPath: projectDir.appendingPathComponent("yarn.lock").path)

        var base: String
        if hasBun {
            base = "bun run \(script.name)"
        } else if hasPnpm {
            base = "pnpm \(script.name)"
        } else if hasYarn {
            base = "yarn \(script.name)"
        } else {
            base = "npm run \(script.name)"
        }

        var args = ""
        if body.contains("vite") {
            args = " -- --host 127.0.0.1 --port \(port)"
        } else if body.contains("next") {
            args = " -- --hostname 127.0.0.1 --port \(port)"
        }

        let env = [
            "PORT": "\(port)",
            "HOST": "127.0.0.1",
            "BROWSER": "none",
        ]
        return (base + args, env)
    }
}
