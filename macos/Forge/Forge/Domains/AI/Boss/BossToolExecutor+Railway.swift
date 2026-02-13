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

        // Fast path first — no AI, just direct API pipeline
        do {
            onSubAgentEvent(deployerLabel, .toolStart(name: "deploy_to_railway", args: "Fast deploy \(deployProject)"))
            let url = try await fastDeployRailway(project: deployProject, label: deployerLabel)
            onSubAgentEvent(deployerLabel, .toolDone(name: "deploy_to_railway", summary: "Deployed: \(url)"))
            return "✅ Deployed to Railway: \(url) — IMPORTANT: Include this URL in your response so the user can click it."
        } catch {
            // Fast path failed — call in the agent to debug
            buildLogger?.logEvent("⚡", "[railway] Fast path failed: \(error.localizedDescription)")
            buildLogger?.logEvent("🔄", "[railway] Calling agent to fix...")
            onSubAgentEvent(deployerLabel, .error("Fast deploy failed, calling agent..."))
        }

        // Agent fallback — Opus first, Codex if Opus fails
        return try await agentDeployRailway(project: deployProject, version: version, label: deployerLabel)
    }

    // MARK: - Fast Path (API)

    private func fastDeployRailway(project: String, label: String) async throws -> String {
        let projectPath = workspace.projectPath(project)
        let serviceName = project.replacingOccurrences(of: "/", with: "-")

        // 1. Pack project files into tar.gz
        onSubAgentEvent(label, .toolStart(name: "railway_pack", args: "Packing project files"))
        let files = workspace.listFiles(project: project).filter { !$0.isDirectory }
        let tarData = try createTarGz(projectPath: projectPath, files: files)
        let tarSizeMB = String(format: "%.1f", Double(tarData.count) / 1_048_576)
        onSubAgentEvent(label, .toolDone(name: "railway_pack", summary: "Packed (\(tarSizeMB) MB)"))
        buildLogger?.logEvent("📦", "[railway] Packed project files (\(tarSizeMB) MB)")

        // 2. Create Railway project → projectId + environmentId
        onSubAgentEvent(label, .toolStart(name: "railway_create_project", args: serviceName))
        let (projectId, environmentId) = try await RailwayAPIService.createProject(name: serviceName)
        onSubAgentEvent(label, .toolDone(name: "railway_create_project", summary: "Project created"))
        buildLogger?.logEvent("🚂", "[railway] Project created: \(serviceName)")

        // 3. Create service → serviceId
        onSubAgentEvent(label, .toolStart(name: "railway_create_service", args: serviceName))
        let serviceId = try await RailwayAPIService.createService(projectId: projectId, name: serviceName)
        onSubAgentEvent(label, .toolDone(name: "railway_create_service", summary: "Service created"))
        buildLogger?.logEvent("🔧", "[railway] Service created: \(serviceId.prefix(8))...")

        // 4. Upload tarball & deploy → deploymentId
        onSubAgentEvent(label, .toolStart(name: "railway_upload", args: "Uploading & deploying"))
        let deploymentId = try await RailwayAPIService.uploadAndDeploy(
            projectId: projectId,
            environmentId: environmentId,
            serviceId: serviceId,
            tarball: tarData
        )
        onSubAgentEvent(label, .toolDone(name: "railway_upload", summary: "Upload started"))
        buildLogger?.logEvent("⬆️", "[railway] Deploy started: \(deploymentId.prefix(8))...")

        // 5. Create public domain → URL
        onSubAgentEvent(label, .toolStart(name: "railway_domain", args: "Requesting domain"))
        let url = try await RailwayAPIService.createDomain(serviceId: serviceId, environmentId: environmentId)
        onSubAgentEvent(label, .toolDone(name: "railway_domain", summary: url))
        buildLogger?.logEvent("🌐", "[railway] Domain: \(url)")

        // 6. Poll status until SUCCESS
        onSubAgentEvent(label, .toolStart(name: "railway_status", args: "Waiting for deploy..."))
        let status = try await RailwayAPIService.pollDeployment(deploymentId: deploymentId)
        onSubAgentEvent(label, .toolDone(name: "railway_status", summary: status))
        buildLogger?.logEvent("✅", "[railway] Deploy status: \(status)")

        // 7. Save railway.json to project dir
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

        ## Railway API (use RailwayAPIService)
        1. `RailwayAPIService.createProject(name:)` → (projectId, environmentId)
        2. `RailwayAPIService.createService(projectId:, name:)` → serviceId
        3. Pack project files into tar.gz, then `RailwayAPIService.uploadAndDeploy(projectId:, environmentId:, serviceId:, tarball:)` → deploymentId
        4. `RailwayAPIService.createDomain(serviceId:, environmentId:)` → URL
        5. `RailwayAPIService.pollDeployment(deploymentId:)` → wait for SUCCESS

        ## Notes
        - Nixpacks auto-detects project type (HTML, Node, React, etc.)
        - For Node servers: ensure PORT env var is used (Railway sets it automatically)
        - For static HTML: Nixpacks will serve it automatically
        - Deploy takes ~30-60 seconds

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
            let allowed: Set<String> = ["list_files", "read_file", "create_file", "edit_file"]
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
            let allowed: Set<String> = ["list_files", "read_file", "create_file", "edit_file"]
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

        if let range = result.text.range(of: #"https://[\w-]+\.up\.railway\.app"#, options: .regularExpression) {
            let url = String(result.text[range])
            // Ensure Railway popover can resolve deploy state even when agent fallback succeeded.
            let serviceName = project.replacingOccurrences(of: "/", with: "-")
            saveRailwayJSON(project: project, serviceName: serviceName, url: url)
            return "✅ Deployed to Railway: \(url) — IMPORTANT: Include this URL in your response so the user can click it."
        }

        return result.text
    }

    // MARK: - Helpers

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
