import Foundation

extension BossToolExecutor {
    // MARK: - Deploy to Railway

    func executeDeployToRailway(_ call: ToolCall) async throws -> String {
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

        let deployerLabel = "railway/\(version)"

        // Fast path first — no AI, just direct CLI pipeline
        do {
            onSubAgentEvent(deployerLabel, .toolStart(name: "deploy_to_railway", args: "Fast deploy \(deployProject)"))
            let url = try await fastDeployRailway(project: deployProject, label: deployerLabel)
            onSubAgentEvent(deployerLabel, .toolDone(name: "deploy_to_railway", summary: "Deployed: \(url)"))
            return "✅ Deployed to \(url) — the URL is already shown to the user as a clickable card. Do NOT repeat the URL in your response."
        } catch {
            // Fast path failed — call in the agent to debug
            buildLogger?.logEvent("⚡", "[railway] Fast path failed: \(error.localizedDescription)")
            buildLogger?.logEvent("🔄", "[railway] Calling agent to fix...")
            onSubAgentEvent(deployerLabel, .error("Fast deploy failed, calling agent..."))
        }

        // Agent fallback — Opus first, Codex if Opus fails
        return try await agentDeployRailway(project: deployProject, version: version, label: deployerLabel)
    }

    // MARK: - Fast Path (no AI)

    private func fastDeployRailway(project: String, label: String) async throws -> String {
        let projectPath = workspace.projectPath(project)
        let serviceName = project.replacingOccurrences(of: "/", with: "-")

        // 1. Copy project files to temp dir (Railway CLI uploads from cwd)
        onSubAgentEvent(label, .toolStart(name: "railway_copy", args: "Copying project files"))
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("railway-\(UUID().uuidString)")
        try copyProjectFiles(from: projectPath, to: tempDir)
        onSubAgentEvent(label, .toolDone(name: "railway_copy", summary: "Files copied to temp dir"))
        buildLogger?.logEvent("📦", "[railway] Copied project files to temp dir")

        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 2. railway init
        onSubAgentEvent(label, .toolStart(name: "railway_init", args: serviceName))
        _ = try await RailwayService.createProject(name: serviceName, cwd: tempDir)
        onSubAgentEvent(label, .toolDone(name: "railway_init", summary: "Project created"))
        buildLogger?.logEvent("🚂", "[railway] Project initialized: \(serviceName)")

        // 3. railway up --detach
        onSubAgentEvent(label, .toolStart(name: "railway_up", args: "Uploading & deploying"))
        _ = try await RailwayService.deploy(serviceName: serviceName, cwd: tempDir)
        onSubAgentEvent(label, .toolDone(name: "railway_up", summary: "Upload started"))
        buildLogger?.logEvent("⬆️", "[railway] Deploy started (detached)")

        // 4. railway domain
        onSubAgentEvent(label, .toolStart(name: "railway_domain", args: "Requesting domain"))
        let url = try await RailwayService.getDomain(serviceName: serviceName, cwd: tempDir)
        onSubAgentEvent(label, .toolDone(name: "railway_domain", summary: url))
        buildLogger?.logEvent("🌐", "[railway] Domain: \(url)")

        // 5. Poll status until SUCCESS
        onSubAgentEvent(label, .toolStart(name: "railway_status", args: "Waiting for deploy..."))
        let status = try await RailwayService.pollStatus(cwd: tempDir, maxAttempts: 30, interval: 2_000_000_000)
        onSubAgentEvent(label, .toolDone(name: "railway_status", summary: status))
        buildLogger?.logEvent("✅", "[railway] Deploy status: \(status)")

        // 6. Save railway.json to project dir
        saveRailwayJSON(project: project, serviceName: serviceName, url: url)

        return url
    }

    // MARK: - Agent Fallback

    private func agentDeployRailway(project: String, version: String, label: String) async throws -> String {
        let files = workspace.listFiles(project: project)
        let fileListing = files
            .filter { !$0.isDirectory }
            .map { "  \($0.path) (\($0.size)B)" }
            .joined(separator: "\n")

        let instructions = """
        Deploy the project "\(project)" to Railway cloud hosting.
        The fast deploy pipeline failed — you may need to debug build errors or dependency issues.

        PROJECT FILES:
        \(fileListing)

        ## Railway CLI Commands
        - `railway init -n "<name>"` — create a new Railway project
        - `railway up --detach --service "<name>"` — deploy via Nixpacks
        - `railway domain --json --service "<name>"` — get the public URL
        - `railway service status --all` — check deploy status (DEPLOYING → SUCCESS)

        ## Notes
        - Nixpacks auto-detects project type (HTML, Node, React, etc.)
        - For Node servers: ensure PORT env var is used (Railway sets it automatically)
        - For static HTML: Nixpacks will serve it automatically
        - Deploy takes ~30-60 seconds

        Copy project files to a temp directory first, then run Railway CLI from there.
        Return the public URL when done.
        """

        let systemPrompt = BossSystemPrompts.railwayDeployer
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
            let allowed: Set<String> = ["list_files", "read_file", "create_file", "edit_file", "run_command"]
            let filteredTools = filterTools(allTools, allowed: allowed, isAnthropic: isAnthropic)

            result = try await AgentLoop().run(
                userMessage: instructions,
                history: [],
                systemPrompt: systemPrompt,
                service: service,
                executor: subExecutor,
                tools: filteredTools,
                maxIterations: 30,
                onEvent: makeEventHandler("[railway/opus]")
            )
        } catch {
            // Codex fallback
            buildLogger?.logEvent("❌", "[railway/opus] Error: \(error.localizedDescription)")
            buildLogger?.logEvent("🔄", "[railway] Retrying with codex...")

            let fallbackService = builderServiceResolver?("codex") ?? serviceResolver(.codex)
            let allowed: Set<String> = ["list_files", "read_file", "create_file", "edit_file", "run_command"]
            let fallbackTools = filterTools(ForgeTools.openAIFormat(), allowed: allowed, isAnthropic: false)

            result = try await AgentLoop().run(
                userMessage: instructions,
                history: [],
                systemPrompt: systemPrompt,
                service: fallbackService,
                executor: subExecutor,
                tools: fallbackTools,
                maxIterations: 30,
                onEvent: makeEventHandler("[railway/codex-retry]")
            )
        }

        if let range = result.text.range(of: #"https://[\w-]+-production\.up\.railway\.app"#, options: .regularExpression) {
            let url = String(result.text[range])
            return "✅ Deployed to \(url) — the URL is already shown to the user as a clickable card. Do NOT repeat the URL in your response."
        }

        return result.text
    }

    // MARK: - Helpers

    /// Copy project files to a temp directory, skipping build artifacts and metadata
    private func copyProjectFiles(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let skipDirs: Set<String> = ["node_modules", ".git", ".next", "dist", "build"]
        let skipFiles: Set<String> = ["build-log.md", "agent-name.txt", "brief.md", "project-name.txt", "sandbox.json", "railway.json", "memory.md", "research.md", "checklist.md"]

        let items = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
        for item in items {
            let name = item.lastPathComponent
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir && skipDirs.contains(name) { continue }
            if !isDir && skipFiles.contains(name) { continue }

            let dest = destination.appendingPathComponent(name)
            try fm.copyItem(at: item, to: dest)
        }
    }

    func saveRailwayJSON(project: String, serviceName: String, url: String) {
        let file = workspace.projectPath(project).appendingPathComponent("railway.json")
        let info: [String: Any] = [
            "service_name": serviceName,
            "url": url,
            "created_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: file)
        }
    }
}
