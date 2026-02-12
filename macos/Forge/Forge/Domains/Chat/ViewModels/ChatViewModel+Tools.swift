import Foundation

extension ChatViewModel {
    // MARK: - Agent Loop (with tools)

    func sendWithTools(
        text: String,
        aiMessages: [AIMessage],
        assistantIndex: Int,
        service: any AIService,
        provider: AIProvider,
        projectName: String,
        promptText: String
    ) {
        // Boss mode: use Gemini Flash as orchestrator when API key is available
        let useBossMode = appState.hasBossKey
        let bossService: any AIService = useBossMode ? appState.bossService : service
        let bossProvider: AIProvider = useBossMode ? .gemini : provider

        let executor: any ToolExecuting
        let bossExecutor: BossToolExecutor?
        let systemPrompt: String
        let tools: [[String: Any]]?
        let buildLogger: BuildLogger?

        if useBossMode {
            let logger = BuildLogger(workspace: appState.workspace, projectName: projectName)
            logger.logBuildStart(prompt: text)
            buildLogger = logger

            let boss = BossToolExecutor(
                workspace: appState.workspace,
                projectName: projectName,
                serviceResolver: { [weak appState] provider in
                    appState?.resolveService(for: provider) ?? service
                },
                builderServiceResolver: { [weak appState] builderName in
                    appState?.resolveBuilderService(for: builderName) ?? service
                },
                onChecklistUpdate: { [weak self] items in
                    self?.checklist.update(items)
                },
                onSubAgentEvent: { [weak self] role, event in
                    guard let self else { return }
                    switch event {
                    case .toolStart(let name, _):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "[\(role)] \(icon) \(self.toolLabel(name))..."
                        self.activityLog.append(icon, self.toolLabel(name) + "...", role: role)
                    case .toolDone(let name, let summary):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "[\(role)] \(icon) \(self.toolLabel(name)) — done\n\(summary)"
                        self.activityLog.append(icon, self.toolLabel(name) + " — done", role: role)
                    case .apiResponse:
                        break // logged by BossToolExecutor's BuildLogger
                    default:
                        break
                    }
                },
                onProjectCreate: { [weak self] name in
                    guard let appState = self?.appState else { return }
                    let isVersionProject = name.contains("/v")
                    if !isVersionProject {
                        // Base project: select it and set preview
                        let projectId = "local:\(name)"
                        appState.setSelectedProjectId(projectId)
                        appState.setLocalPreviewURL(appState.workspace.projectPath(name))
                        appState.setLocalFiles(appState.workspace.listFiles(project: name))
                    }
                    // Always refresh sidebar so version projects show up
                    appState.refreshLocalProjects()
                    Task { _ = try? await appState.workspace.ensureGitRepository(project: name) }
                },
                onFileWrite: { [weak self] in
                    self?.appState.refreshPreview()
                },
                onBuilderDone: { [weak self] versionProjectName in
                    guard let self, !self.hasFirstBuilderLoaded else { return }
                    self.hasFirstBuilderLoaded = true
                    let appState = self.appState
                    // Load the first completed builder's project into the preview
                    let projectId = "local:\(versionProjectName)"
                    appState.setSelectedProjectId(projectId)
                    appState.setLocalFiles(appState.workspace.listFiles(project: versionProjectName))
                    // Use resolvePreviewURL to start dev server for framework projects
                    Task {
                        let url = await appState.workspace.resolvePreviewURL(project: versionProjectName)
                        appState.setLocalPreviewURL(url)
                        appState.refreshPreview()
                    }
                    appState.refreshLocalProjects()
                }
            )
            boss.buildLogger = logger
            boss.memoryService = memoryService
            executor = boss
            bossExecutor = boss
            let hasProject = !projectName.isEmpty
            systemPrompt = BossSystemPrompts.boss + (hasProject
                ? "\n\nCONTEXT: Project '\(projectName)' already exists. Do NOT call create_project. Skip discovery if the user is giving follow-up instructions."
                : "\n\nCONTEXT: No project exists yet. Start with Discovery to understand what the user wants.")
            tools = ForgeTools.bossOpenAIFormat()
        } else {
            executor = ToolExecutor(
                workspace: appState.workspace,
                projectName: projectName,
                onFileWrite: { [weak self] in
                    self?.appState.refreshPreview()
                }
            )
            bossExecutor = nil
            buildLogger = nil
            systemPrompt = SystemPrompts.websiteBuilderWithTools
            tools = nil
        }

        streamTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                isLoading = false
                messages[assistantIndex].content = useBossMode ? "Planning..." : "Thinking..."
                if useBossMode {
                    checklist.reset()
                    activityLog.reset()
                    activityLog.append("🚀", "Build started")
                    self.hasFirstBuilderLoaded = false
                }

                let result = try await agentLoop.run(
                    userMessage: text,
                    history: Array(aiMessages.dropLast()), // exclude the current user message
                    systemPrompt: systemPrompt,
                    service: bossService,
                    executor: executor,
                    tools: tools,
                    rawHistory: useBossMode ? (agentRawHistory.isEmpty ? nil : agentRawHistory) : nil
                ) { [weak self] event in
                    guard let self else { return }
                    switch event {
                    case .thinking:
                        break
                    case .toolStart(let name, _):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "\(icon) \(self.toolLabel(name))..."
                        self.activityLog.append(icon, self.toolLabel(name) + "...")
                        buildLogger?.logEvent(icon, self.toolLabel(name))
                    case .toolDone(let name, let summary):
                        let icon = self.toolIcon(name)
                        messages[assistantIndex].content = "\(icon) \(self.toolLabel(name)) — done\n\(summary)"
                        self.activityLog.append(icon, self.toolLabel(name) + " — done")
                    case .text:
                        break // final text handled below
                    case .apiResponse(let input, let output):
                        buildLogger?.logEvent("📡", "Boss API", tokens: "\(input)→\(output)")
                    case .error(let msg):
                        messages[assistantIndex].content = "Error: \(msg)"
                        self.activityLog.append("❌", msg)
                        buildLogger?.logEvent("❌", msg)
                    }
                }

                // Set final response
                messages[assistantIndex].content = result.text.isEmpty ? "Done." : result.text

                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                if useBossMode {
                    activityLog.append("✅", String(format: "Done in %.0fs — %d input, %d output tokens", totalTime, result.totalInputTokens, result.totalOutputTokens))
                    buildLogger?.logBuildDone(totalInput: result.totalInputTokens, totalOutput: result.totalOutputTokens)
                }
                requestLogger.log(provider: bossProvider, projectId: appState.selectedProjectId, prompt: promptText, totalTime: totalTime, ttft: 0, chunks: 0, chars: result.text.count, inputTokens: result.totalInputTokens, outputTokens: result.totalOutputTokens)

                // Use the (potentially updated) project name from BossToolExecutor
                let finalProjectName = bossExecutor?.projectName ?? projectName
                if !finalProjectName.isEmpty {
                    await projectUpdater.commitAndRefresh(projectName: finalProjectName, commitMessage: text)
                }

                // Update Gemini context cache with full conversation (Boss only)
                if useBossMode {
                    agentRawHistory = result.messages
                    saveAgentHistory()
                    await appState.bossService.updateCache(
                        systemPrompt: systemPrompt,
                        messages: result.messages
                    )
                }

                saveChatHistory()
            } catch {
                if !Task.isCancelled {
                    messages[assistantIndex].content = "Error: \(error.localizedDescription)"
                }
                saveChatHistory()
            }
            isStreaming = false
            isLoading = false
        }
    }

    // MARK: - Tool Display Helpers

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "list_files": return "📁"
        case "read_file": return "📄"
        case "create_file": return "📝"
        case "edit_file": return "✏️"
        case "delete_file": return "🗑️"
        case "web_search": return "🔍"
        case "delegate_task": return "👥"
        case "update_checklist": return "📋"
        case "create_project": return "🏗️"
        case "build_version": return "🏗️"
        case "generate_image": return "🎨"
        case "restyle_image": return "🖌️"
        case "download_image": return "⬇️"
        case "take_screenshot": return "📸"
        case "review_screenshot": return "🔎"
        default: return "🔧"
        }
    }

    private func toolLabel(_ name: String) -> String {
        switch name {
        case "list_files": return "Listing files"
        case "read_file": return "Reading file"
        case "create_file": return "Creating file"
        case "edit_file": return "Editing file"
        case "delete_file": return "Deleting file"
        case "web_search": return "Searching the web"
        case "delegate_task": return "Delegating task"
        case "update_checklist": return "Updating checklist"
        case "create_project": return "Creating project"
        case "build_version": return "Building version"
        case "generate_image": return "Generating image"
        case "restyle_image": return "Restyling image"
        case "download_image": return "Downloading image"
        case "take_screenshot": return "Taking screenshot"
        case "review_screenshot": return "Reviewing screenshot"
        default: return name
        }
    }
}
