import Foundation

extension BossToolExecutor {
    // MARK: - Deploy to Sandbox

    func executeDeployToSandbox(_ call: ToolCall) async throws -> String {
        let args = parseArguments(call.arguments)
        guard let version = args["version"] as? String else {
            throw ToolError.missingParameter("version")
        }

        // Resolve the project to deploy (e.g. "my-site/v1")
        let deployProject: String
        if projectName.contains("/") {
            let parent = projectName.components(separatedBy: "/").first ?? projectName
            deployProject = "\(parent)/\(version)"
        } else {
            deployProject = "\(projectName)/\(version)"
        }

        guard workspace.projectExists(deployProject) else {
            return "Error: project '\(deployProject)' not found."
        }

        let deployerLabel = "deploy/\(version)"

        // Fast path first — no AI, just direct pipeline
        do {
            onSubAgentEvent(deployerLabel, .toolStart(name: "deploy_to_sandbox", args: "Fast deploy \(deployProject)"))
            let url = try await fastDeploy(project: deployProject, label: deployerLabel)
            onSubAgentEvent(deployerLabel, .toolDone(name: "deploy_to_sandbox", summary: "Deployed: \(url)"))
            return "✅ Deployed to \(url) — the URL is already shown to the user as a clickable card. Do NOT repeat the URL in your response."
        } catch {
            // Fast path failed — call in the agent to debug
            buildLogger?.logEvent("⚡", "[deploy] Fast path failed: \(error.localizedDescription)")
            buildLogger?.logEvent("🔄", "[deploy] Calling agent to fix...")
            onSubAgentEvent(deployerLabel, .error("Fast deploy failed, calling agent..."))
        }

        // Agent fallback — Opus first, Codex if Opus fails
        return try await agentDeploy(project: deployProject, version: version, label: deployerLabel)
    }

    // MARK: - Fast Path (no AI)

    private func fastDeploy(project: String, label: String) async throws -> String {
        let files = workspace.listFiles(project: project)
        let projectFiles = files.filter { !$0.isDirectory }
        let skipPrefixes = ["node_modules/", ".git/", ".next/", "dist/", "build/"]
        let skipFiles: Set<String> = ["build-log.md", "agent-name.txt", "brief.md", "project-name.txt", "sandbox.json", "memory.md", "research.md", "checklist.md"]

        let uploadableFiles = projectFiles.filter { file in
            !skipPrefixes.contains(where: { file.path.hasPrefix($0) }) && !skipFiles.contains(file.path)
        }

        // Detect project type
        let hasPackageJson = projectFiles.contains { $0.path == "package.json" }
        let hasIndexHtml = projectFiles.contains { $0.path == "index.html" }

        // 1. Create sandbox
        onSubAgentEvent(label, .toolStart(name: "sandbox_create", args: project))
        let sandboxId = try await DaytonaService.createSandbox(name: project.replacingOccurrences(of: "/", with: "-"))
        onSubAgentEvent(label, .toolDone(name: "sandbox_create", summary: "ID: \(sandboxId.prefix(8))..."))
        buildLogger?.logEvent("📦", "[deploy] Sandbox created: \(sandboxId.prefix(8))...")

        // 2. Pack files into tar.gz, upload as single file, extract in sandbox
        onSubAgentEvent(label, .toolStart(name: "sandbox_upload", args: "\(uploadableFiles.count) files"))
        let projectPath = workspace.projectPath(project)
        let tarData = try createTarGz(projectPath: projectPath, files: uploadableFiles)
        let tarSizeMB = String(format: "%.1f", Double(tarData.count) / 1_048_576)
        buildLogger?.logEvent("📦", "[deploy] Packed \(uploadableFiles.count) files (\(tarSizeMB) MB)")

        // Single upload
        try await DaytonaService.uploadFile(sandboxId: sandboxId, remotePath: "/home/daytona/site.tar.gz", localData: tarData)

        // Extract in sandbox
        let extract = try await DaytonaService.exec(sandboxId: sandboxId, command: "mkdir -p /home/daytona/site && tar xzf /home/daytona/site.tar.gz -C /home/daytona/site && rm /home/daytona/site.tar.gz", timeout: 30)
        guard extract.exitCode == 0 else {
            throw DeployFastPathError.uploadFailed(extract.output)
        }
        onSubAgentEvent(label, .toolDone(name: "sandbox_upload", summary: "\(uploadableFiles.count) files (\(tarSizeMB) MB)"))
        buildLogger?.logEvent("⬆️", "[deploy] Uploaded & extracted \(uploadableFiles.count) files")

        // 3. Start server based on project type
        let port = 3000
        if hasPackageJson {
            // Framework project: install, build, serve
            onSubAgentEvent(label, .toolStart(name: "sandbox_exec", args: "npm install"))
            let install = try await DaytonaService.exec(sandboxId: sandboxId, command: "cd /home/daytona/site && npm install 2>&1", timeout: 90)
            guard install.exitCode == 0 else {
                throw DeployFastPathError.npmInstallFailed(install.output)
            }
            onSubAgentEvent(label, .toolDone(name: "sandbox_exec", summary: "npm install done"))

            // Check if there's a build script
            let pkgContent = try? workspace.readFile(project: project, path: "package.json")
            let hasBuildScript = pkgContent?.contains("\"build\"") ?? false

            if hasBuildScript {
                onSubAgentEvent(label, .toolStart(name: "sandbox_exec", args: "npm run build"))
                let build = try await DaytonaService.exec(sandboxId: sandboxId, command: "cd /home/daytona/site && npm run build 2>&1", timeout: 90)
                guard build.exitCode == 0 else {
                    throw DeployFastPathError.buildFailed(build.output)
                }
                onSubAgentEvent(label, .toolDone(name: "sandbox_exec", summary: "Build done"))

                // Detect output folder (dist/ or build/) and serve with python (always available, no download needed)
                let detectDir = try await DaytonaService.exec(sandboxId: sandboxId, command: "cd /home/daytona/site && if [ -d dist ]; then echo dist; elif [ -d build ]; then echo build; else echo site; fi", timeout: 5)
                let servePath = detectDir.output.trimmingCharacters(in: .whitespacesAndNewlines)
                let serveDir = servePath == "site" ? "/home/daytona/site" : "/home/daytona/site/\(servePath)"
                _ = try await DaytonaService.exec(sandboxId: sandboxId, command: "nohup python3 -m http.server \(port) -d \(serveDir) > /dev/null 2>&1 &", timeout: 10)
            } else if hasIndexHtml {
                // Has package.json but no build script and has index.html — use python
                _ = try await DaytonaService.exec(sandboxId: sandboxId, command: "nohup python3 -m http.server \(port) -d /home/daytona/site > /dev/null 2>&1 &", timeout: 10)
            } else {
                // Dev server (e.g. vite) — try npm start, fall back to python
                _ = try await DaytonaService.exec(sandboxId: sandboxId, command: "cd /home/daytona/site && nohup npm start > /dev/null 2>&1 &", timeout: 10)
            }
        } else {
            // Vanilla HTML — python server
            onSubAgentEvent(label, .toolStart(name: "sandbox_exec", args: "Starting server"))
            _ = try await DaytonaService.exec(sandboxId: sandboxId, command: "nohup python3 -m http.server \(port) -d /home/daytona/site > /dev/null 2>&1 &", timeout: 10)
            onSubAgentEvent(label, .toolDone(name: "sandbox_exec", summary: "Server started"))
        }

        // 4. Wait briefly then verify
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let check = try await DaytonaService.exec(sandboxId: sandboxId, command: "curl -s -o /dev/null -w '%{http_code}' http://localhost:\(port)", timeout: 10)
        guard check.output.contains("200") else {
            throw DeployFastPathError.serverNotResponding(check.output)
        }

        // 5. Build URL and persist
        let url = DaytonaService.previewURL(sandboxId: sandboxId, port: port)
        saveSandboxJSON(project: project, sandboxId: sandboxId, previewURL: url, port: port)
        buildLogger?.logEvent("✅", "[deploy] Live: \(url)")

        return url
    }

    // MARK: - Agent Fallback

    private func agentDeploy(project: String, version: String, label: String) async throws -> String {
        let files = workspace.listFiles(project: project)
        let fileListing = files
            .filter { !$0.isDirectory }
            .map { "  \($0.path) (\($0.size)B)" }
            .joined(separator: "\n")

        let instructions = """
        Deploy the project "\(project)" to a Daytona sandbox.
        The fast deploy pipeline failed — you may need to debug build errors or dependency issues.

        PROJECT FILES:
        \(fileListing)

        Upload all project files to /home/daytona/site/ in the sandbox, then install dependencies and start a server.
        Return the public preview URL when done.
        """

        let systemPrompt = BossSystemPrompts.deployer
        let subExecutor = ToolExecutor(workspace: workspace, projectName: project, onFileWrite: onFileWrite)

        let makeEventHandler: (String) -> (AgentEvent) -> Void = { [onSubAgentEvent, weak buildLogger] tag in
            return { event in
                onSubAgentEvent(label, event)
                switch event {
                case .toolStart(let name, let args):
                    buildLogger?.logEvent("🔧", "\(tag) `\(name)` — \(String(args.prefix(80)))")
                case .toolDone(let name, let summary):
                    buildLogger?.logEvent("✓", "\(tag) `\(name)` → \(String(summary.prefix(80)))")
                case .apiResponse(let input, let output):
                    buildLogger?.logEvent("📡", "\(tag) API call", tokens: "\(input)→\(output)")
                case .error(let msg):
                    buildLogger?.logEvent("❌", "\(tag) \(msg)")
                default:
                    break
                }
            }
        }

        // Try Opus first
        var result: AgentResult
        do {
            let service = builderServiceResolver?("opus") ?? serviceResolver(.claude)
            let isAnthropic = service.provider == .claude
            let allTools: [[String: Any]] = isAnthropic ? ForgeTools.anthropicFormat() : ForgeTools.openAIFormat()
            let filteredTools = filterTools(allTools, allowed: SubAgentRole.deployer.allowedTools, isAnthropic: isAnthropic)

            result = try await AgentLoop().run(
                userMessage: instructions,
                history: [],
                systemPrompt: systemPrompt,
                service: service,
                executor: subExecutor,
                tools: filteredTools,
                maxIterations: SubAgentRole.deployer.maxIterations,
                onEvent: makeEventHandler("[deploy/opus]")
            )
        } catch {
            // Codex fallback
            buildLogger?.logEvent("❌", "[deploy/opus] Error: \(error.localizedDescription)")
            buildLogger?.logEvent("🔄", "[deploy] Retrying with codex...")

            let fallbackService = builderServiceResolver?("codex") ?? serviceResolver(.codex)
            let fallbackTools = filterTools(ForgeTools.openAIFormat(), allowed: SubAgentRole.deployer.allowedTools, isAnthropic: false)

            result = try await AgentLoop().run(
                userMessage: instructions,
                history: [],
                systemPrompt: systemPrompt,
                service: fallbackService,
                executor: subExecutor,
                tools: fallbackTools,
                maxIterations: SubAgentRole.deployer.maxIterations,
                onEvent: makeEventHandler("[deploy/codex-retry]")
            )
        }

        if let range = result.text.range(of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+"#, options: .regularExpression) {
            let url = String(result.text[range])
            return "✅ Deployed to \(url) — the URL is already shown to the user as a clickable card. Do NOT repeat the URL in your response."
        }

        return result.text
    }

    // MARK: - Helpers

    /// Create a tar.gz archive from project files, returns the archive data
    func createTarGz(projectPath: URL, files: [LocalFileInfo]) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tarFile = tempDir.appendingPathComponent("site.tar.gz")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Build exclude list and tar command
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "czf", tarFile.path,
            "--exclude", "node_modules",
            "--exclude", ".git",
            "--exclude", ".next",
            "--exclude", "dist",
            "--exclude", "build",
            "--exclude", "build-log.md",
            "--exclude", "agent-name.txt",
            "--exclude", "brief.md",
            "--exclude", "project-name.txt",
            "--exclude", "sandbox.json",
            "--exclude", "memory.md",
            "--exclude", "research.md",
            "--exclude", "checklist.md",
            "-C", projectPath.path,
            ".",
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw DeployFastPathError.tarFailed(output)
        }

        return try Data(contentsOf: tarFile)
    }

    private func saveSandboxJSON(project: String, sandboxId: String, previewURL: String, port: Int) {
        let file = workspace.projectPath(project).appendingPathComponent("sandbox.json")
        let info: [String: Any] = [
            "sandbox_id": sandboxId,
            "preview_url": previewURL,
            "port": port,
            "created_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: file)
        }
    }
}

// MARK: - Fast Path Errors

enum DeployFastPathError: LocalizedError {
    case tarFailed(String)
    case uploadFailed(String)
    case npmInstallFailed(String)
    case buildFailed(String)
    case serverNotResponding(String)

    var errorDescription: String? {
        switch self {
        case .tarFailed(let output): return "tar failed: \(output.prefix(200))"
        case .uploadFailed(let output): return "Upload/extract failed: \(output.prefix(200))"
        case .npmInstallFailed(let output): return "npm install failed: \(output.prefix(200))"
        case .buildFailed(let output): return "Build failed: \(output.prefix(200))"
        case .serverNotResponding(let status): return "Server not responding (status: \(status))"
        }
    }
}
