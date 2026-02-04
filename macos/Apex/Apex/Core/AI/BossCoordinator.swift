import SwiftUI
import Observation

/// Manages 1-3 BossInstances. Owns workspace creation, template copying, memory persistence.
/// Supports two-phase flow: research (Claude) → parallel build (all agents).
@MainActor
@Observable
class BossCoordinator {

    // MARK: - Types

    enum BossPhase {
        case idle
        case researching
        case building
    }

    enum WorkspaceRole {
        case solo
        case research
        case builder
    }

    // MARK: - State

    var isActive = false
    var bosses: [BossInstance] = []
    var selectedBossId: String?
    var researchBoss: BossInstance?
    var phase: BossPhase = .idle

    /// Whether we already linked the workspace as a local project
    private var projectLinked = false

    /// Bosses that have been linked as local projects (tracks per-boss to allow incremental linking)
    private var linkedBossIds: Set<String> = []

    /// Build-phase config (stored on first message, used when builders start + checklist generation)
    private var buildConfig = GenerationConfig()
    private var imageInstruction: String?
    private var pendingInspirationImage: NSImage?
    private var projectDisplayName: String?
    private var sessionName: String?

    weak var delegate: BossCoordinatorDelegate?

    init(delegate: BossCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Computed

    /// The currently selected boss (or first if none selected)
    var selectedBoss: BossInstance? {
        if let id = selectedBossId {
            if let research = researchBoss, research.id == id {
                return research
            }
            return bosses.first { $0.id == id }
        }
        return bosses.first
    }

    /// Messages for the selected boss
    var messages: [ChatMessage] {
        selectedBoss?.messages ?? []
    }

    /// Workspace files for the selected boss
    var workspaceFiles: [LocalFileInfo] {
        selectedBoss?.workspaceFiles ?? []
    }

    /// Workspace URL for the selected boss
    var workspace: URL? {
        selectedBoss?.workspace
    }

    /// Whether any boss is currently processing
    var isProcessing: Bool {
        let builderProcessing = bosses.contains { $0.service.isProcessing }
        let researchProcessing = researchBoss?.service.isProcessing ?? false
        return builderProcessing || researchProcessing
    }

    /// Whether we have multiple bosses running (two-phase mode)
    var isMultiBoss: Bool {
        researchBoss != nil || bosses.count > 1
    }

    // MARK: - Actions

    /// Toggle boss mode on/off
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(count: 1, vectors: [nil], agents: [.claude])
        }
    }

    /// Activate with specified boss count, vectors, and agents
    func activate(count: Int, vectors: [String?], agents: [AIAgent] = [.claude]) {
        if isActive {
            resetSession()
        }

        isActive = true

        if agents.count > 1 {
            // Two-phase mode: separate research boss + builder bosses
            researchBoss = BossInstance(id: "research", agent: .gemini)
            bosses = agents.enumerated().map { i, agent in
                let vector = i < vectors.count ? vectors[i] : nil
                return BossInstance(id: "boss-\(i)", agent: agent, vector: vector)
            }
            phase = .idle
            selectedBossId = researchBoss?.id
        } else {
            // Single-agent mode: no research boss, current behavior
            researchBoss = nil
            bosses = agents.enumerated().map { i, agent in
                let vector = i < vectors.count ? vectors[i] : nil
                return BossInstance(id: "boss-\(i)", agent: agent, vector: vector)
            }
            phase = .building
            selectedBossId = bosses.first?.id
        }
    }

    /// Deactivate all bosses
    func deactivate() {
        stopAll()
        isActive = false
        bosses = []
        researchBoss = nil
        selectedBossId = nil
        phase = .idle
    }

    /// Store build-phase config before sending the first message
    func configureBuild(config: GenerationConfig, imageInstruction: String?, inspirationImage: NSImage?, projectName: String? = nil) {
        self.buildConfig = config
        self.imageInstruction = imageInstruction
        self.pendingInspirationImage = inspirationImage
        self.projectDisplayName = projectName
    }

    /// Send a message — routes to research (first message) or selected builder (follow-ups)
    func send(_ text: String, setLoading: @escaping (Bool) -> Void) {
        if researchBoss != nil && phase == .idle {
            // First message in two-phase mode: start research
            startTwoPhaseFlow(text, setLoading: setLoading)
        } else if isMultiBoss, let selected = selectedBoss, bosses.contains(where: { $0.id == selected.id }) {
            // Follow-up goes to the selected builder only
            sendToBoss(selected, text: text, setLoading: setLoading)
        } else {
            // Solo mode: clear previous project on first message
            if bosses.first?.workspace == nil {
                delegate?.setPages([])
                delegate?.setLocalPreviewURL(nil)
                delegate?.setSelectedProjectId(nil)
            }
            for boss in bosses {
                sendToBoss(boss, text: text, setLoading: setLoading)
            }
        }
    }

    /// Resume boss mode for an existing local project workspace (e.g. when user wants to refine a layout)
    func resumeForLocalProject(_ projectId: String) {
        guard let projectName = delegate?.localProjectName(from: projectId) else { return }
        let ws = LocalWorkspaceService.shared
        let workspaceURL = ws.projectPath(projectName)
        guard FileManager.default.fileExists(atPath: workspaceURL.path) else { return }

        // If we already have an active boss for this workspace, keep it (preserves session)
        let bossId = (projectName as NSString).lastPathComponent
        if isActive, let existing = bosses.first(where: { $0.id == bossId }) {
            selectedBossId = existing.id
            return
        }

        // Determine agent from agent-name.txt
        let agentFile = workspaceURL.appendingPathComponent("agent-name.txt")
        let agentName = (try? String(contentsOf: agentFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let agent = AIAgent(rawValue: agentName ?? "") ?? .claude

        let boss = BossInstance(id: bossId, agent: agent)
        boss.workspace = workspaceURL
        boss.loadMessages()

        // Restore Claude session ID so --resume is used
        boss.service.restoreSession(from: workspaceURL)

        isActive = true
        bosses = [boss]
        researchBoss = nil
        phase = .building
        selectedBossId = boss.id
        projectLinked = true
    }

    /// Select the boss tab that matches a sidebar project selection
    func selectBossForProject(_ projectId: String?) {
        guard let projectId, projectId.hasPrefix("local:") else { return }
        let name = String(projectId.dropFirst(6))
        let bossId = (name as NSString).lastPathComponent

        if let research = researchBoss, research.id == bossId {
            selectedBossId = research.id
        } else if bosses.contains(where: { $0.id == bossId }) {
            selectedBossId = bossId
        } else {
            // No active boss for this layout — resume it (loads workspace + messages)
            resumeForLocalProject(projectId)
        }
    }

    /// Stop all running boss processes
    func stopAll() {
        researchBoss?.service.stop()
        for boss in bosses {
            boss.service.stop()
        }
    }

    /// Reset session — clears messages, cleans workspace, starts fresh
    func resetSession() {
        LocalWorkspaceService.shared.cleanOldWorkspaces()

        if let research = researchBoss {
            research.messages = []
            research.workspaceFiles = []
            research.workspace = nil
            research.service.reset()
        }

        for boss in bosses {
            boss.messages = []
            boss.workspaceFiles = []
            boss.workspace = nil
            boss.service.reset()
        }

        phase = researchBoss != nil ? .idle : .building
        projectLinked = false
        linkedBossIds = []
        sessionName = nil
        buildConfig = GenerationConfig()
        imageInstruction = nil
        pendingInspirationImage = nil
        projectDisplayName = nil
    }

    // MARK: - Two-Phase Flow

    private func startTwoPhaseFlow(_ text: String, setLoading: @escaping (Bool) -> Void) {
        guard let research = researchBoss else { return }

        phase = .researching
        selectedBossId = research.id

        // Clear previous project state so the user sees a fresh canvas
        delegate?.setPages([])
        delegate?.setLocalPreviewURL(nil)
        delegate?.setSelectedProjectId(nil)

        // Build research prompt with config-driven instructions
        var researchInstructions = [String]()
        if buildConfig.skipClarification {
            researchInstructions.append("Do NOT ask any clarification questions — write brief.md immediately from the user's information, then proceed to RESEARCH.")
        }
        if !buildConfig.webSearchCompany {
            researchInstructions.append("Do NOT web search for the company.")
        }
        if !buildConfig.scrapeCompanySite {
            researchInstructions.append("Do NOT visit or scrape the company website.")
        }
        if !buildConfig.findInspirationSites {
            researchInstructions.append("Skip searching for inspiration sites.")
        } else if buildConfig.inspirationSiteCount != 3 {
            researchInstructions.append("Find exactly \(buildConfig.inspirationSiteCount) inspiration sites.")
        }

        let instructions = researchInstructions.isEmpty
            ? "Write brief.md from the user's information, then proceed to RESEARCH."
            : researchInstructions.joined(separator: "\n")

        let researchPrompt = """
        This is the complete project brief from the user.

        \(instructions)

        User's request:
        \(text)
        """

        // Pre-create builder workspaces while research runs (template copy + git init)
        for boss in bosses where boss.workspace == nil {
            boss.workspace = createWorkspace(for: boss, role: .builder)
        }

        // Show the new session in the sidebar immediately
        delegate?.refreshLocalProjects()

        Task {
            // Phase 1: Research
            await awaitableSend(research, text: researchPrompt, role: .research, setLoading: setLoading)

            // Phase 2: Build
            await startBuildPhase()
        }
    }

    /// Send a message to a boss and await completion
    private func awaitableSend(
        _ boss: BossInstance,
        text: String,
        role: WorkspaceRole = .solo,
        setLoading: @escaping (Bool) -> Void
    ) async {
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        boss.messages.append(userMessage)
        setLoading(true)

        if boss.workspace == nil {
            boss.workspace = createWorkspace(for: boss, role: role)
        }

        // Save inspiration image to workspace if provided
        if let ws = boss.workspace {
            saveInspirationImage(to: ws)
        }

        var responseText = ""
        var hasStartedResponse = false

        do {
            try await boss.service.send(
                message: text,
                workingDirectory: boss.workspace,
                vector: boss.vector
            ) { [weak self, weak boss] line in
                Task { @MainActor in
                    guard let self, let boss else { return }

                    if !hasStartedResponse {
                        hasStartedResponse = true
                        setLoading(false)
                        responseText = line
                        let msg = ChatMessage(role: .assistant, content: responseText, timestamp: Date())
                        boss.messages.append(msg)
                    } else {
                        responseText += "\n" + line
                        boss.updateLastMessage(content: responseText)
                    }
                }
            }

            // Let pending onLine Tasks flush before reading responseText
            await Task.yield()

            if !hasStartedResponse {
                setLoading(false)
                let msg = ChatMessage(role: .assistant, content: "(No response from boss)", timestamp: Date())
                boss.messages.append(msg)
            }

            boss.refreshWorkspaceFiles()
            boss.persistMessages()
            saveMemories(from: boss)

        } catch {
            setLoading(false)
            if hasStartedResponse {
                boss.updateLastMessage(content: responseText + "\n\nError: \(error.localizedDescription)")
            } else {
                let msg = ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", timestamp: Date())
                boss.messages.append(msg)
            }
            boss.persistMessages()
        }
    }

    /// Start the build phase — copy research files to each builder and fire them all
    private func startBuildPhase() async {
        guard let research = researchBoss, let researchWorkspace = research.workspace else { return }

        phase = .building
        selectedBossId = bosses.first?.id

        // Create workspaces and copy research files for each builder
        for boss in bosses {
            if boss.workspace == nil {
                boss.workspace = createWorkspace(for: boss, role: .builder)
            }
            guard let bossWorkspace = boss.workspace else { continue }
            copyResearchFiles(from: researchWorkspace, to: bossWorkspace)
            saveInspirationImage(to: bossWorkspace)
        }

        // Build message with config instructions
        var buildMessage = "Research is done. Read brief.md and research.md, then follow your checklist — start with VECTOR (pick your own unique design direction), then BUILD."

        if let imgInst = imageInstruction {
            buildMessage += "\n\nImage approach: \(imgInst)"
        }
        if !buildConfig.webSearchDuringLayout {
            buildMessage += "\nDo NOT search the web while building — work only with the research files."
        }
        if pendingInspirationImage != nil {
            buildMessage += "\nSee inspiration.jpg in the workspace for visual reference."
        }

        for boss in bosses {
            sendToBoss(boss, text: buildMessage, setLoading: { _ in })
        }
    }

    /// Save pending inspiration image to a workspace
    private func saveInspirationImage(to workspace: URL) {
        guard let image = pendingInspirationImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

        let dst = workspace.appendingPathComponent("inspiration.jpg")
        try? jpegData.write(to: dst)
    }

    /// Copy brief.md, research.md, and images/ from research workspace to builder workspace
    private func copyResearchFiles(from source: URL, to destination: URL) {
        let fm = FileManager.default
        let filesToCopy = ["brief.md", "research.md"]

        for file in filesToCopy {
            let src = source.appendingPathComponent(file)
            let dst = destination.appendingPathComponent(file)
            guard fm.fileExists(atPath: src.path) else { continue }
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: src, to: dst)
        }

        // Copy images directory
        let imagesSrc = source.appendingPathComponent("images")
        let imagesDst = destination.appendingPathComponent("images")
        if fm.fileExists(atPath: imagesSrc.path) {
            try? fm.removeItem(at: imagesDst)
            try? fm.copyItem(at: imagesSrc, to: imagesDst)
        }
    }

    // MARK: - Private: Send

    private func sendToBoss(_ boss: BossInstance, text: String, setLoading: @escaping (Bool) -> Void) {
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        boss.messages.append(userMessage)
        setLoading(true)

        // For refine messages, prepend a short instruction so the agent responds in chat first
        let actualText: String
        if projectLinked {
            actualText = """
            IMPORTANT: First reply to the user in chat confirming what you'll do (1-2 sentences), then make the changes to the files.

            User request: \(text)
            """
        } else {
            actualText = text
        }

        Task {
            if boss.workspace == nil {
                boss.workspace = createWorkspace(for: boss, role: researchBoss == nil ? .solo : .builder)
            }

            // Save inspiration image for solo mode (first message only)
            if let ws = boss.workspace, researchBoss == nil {
                saveInspirationImage(to: ws)
            }

            var responseText = ""
            var hasStartedResponse = false

            do {
                try await boss.service.send(
                    message: actualText,
                    workingDirectory: boss.workspace,
                    vector: boss.vector
                ) { [weak self, weak boss] line in
                    Task { @MainActor in
                        guard let self, let boss else { return }

                        if !hasStartedResponse {
                            hasStartedResponse = true
                            setLoading(false)
                            responseText = line
                            let msg = ChatMessage(role: .assistant, content: responseText, timestamp: Date())
                            boss.messages.append(msg)
                        } else {
                            responseText += "\n" + line
                            boss.updateLastMessage(content: responseText)
                        }
                    }
                }

                // Let pending onLine Tasks flush before reading responseText
                await Task.yield()

                if !hasStartedResponse {
                    setLoading(false)
                    let msg = ChatMessage(role: .assistant, content: "(No response from boss)", timestamp: Date())
                    boss.messages.append(msg)
                }

                boss.refreshWorkspaceFiles()
                boss.persistMessages()
                saveMemories(from: boss)

                if let serverProjectId = extractServerProjectId(from: responseText) {
                    linkServerProject(serverProjectId)
                } else if !linkedBossIds.contains(boss.id) {
                    // First completion for this builder — link it as a project
                    await commitVersion(boss: boss, message: "Initial build")
                    linkWorkspaceAsProject(boss: boss)
                    linkedBossIds.insert(boss.id)
                } else {
                    let shortMessage = String(text.prefix(72))
                    await commitVersion(boss: boss, message: shortMessage)
                    reloadLocalPreview(boss: boss)
                }

            } catch {
                setLoading(false)
                if hasStartedResponse {
                    boss.updateLastMessage(content: responseText + "\n\nError: \(error.localizedDescription)")
                } else {
                    let msg = ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", timestamp: Date())
                    boss.messages.append(msg)
                }
                boss.persistMessages()
            }
        }
    }

    // MARK: - Workspace Creation

    private func createWorkspace(for boss: BossInstance, role: WorkspaceRole = .solo) -> URL {
        let ws = LocalWorkspaceService.shared

        // Session-level directory — generated once per session, shared by all bosses
        let resolvedSessionName: String
        if let existing = sessionName {
            resolvedSessionName = existing
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmm"
            let newName = "session-\(dateFormatter.string(from: Date()))"
            sessionName = newName
            resolvedSessionName = newName
        }
        let sessionURL = ws.projectPath(resolvedSessionName)

        // Boss subdirectory
        let bossURL = sessionURL.appendingPathComponent(boss.id)

        try? FileManager.default.createDirectory(at: bossURL, withIntermediateDirectories: true)

        // Write project name to session directory (shared by all bosses)
        if let name = projectDisplayName, !name.isEmpty {
            let nameFile = sessionURL.appendingPathComponent("project-name.txt")
            if !FileManager.default.fileExists(atPath: nameFile.path) {
                try? name.write(to: nameFile, atomically: true, encoding: .utf8)
            }
        }

        // Write agent name so sidebar can display it
        let agentFile = bossURL.appendingPathComponent("agent-name.txt")
        if !FileManager.default.fileExists(atPath: agentFile.path) {
            try? boss.agent.rawValue.write(to: agentFile, atomically: true, encoding: .utf8)
        }

        copyTemplates(to: bossURL, role: role)
        initGitRepo(at: bossURL)
        initialCommit(at: bossURL)
        return bossURL
    }

    /// Copy templates from app bundle into the workspace, using role-specific skill and checklist files
    private func copyTemplates(to workspace: URL, role: WorkspaceRole = .solo) {
        guard let templateDir = Bundle.main.url(forResource: "boss-templates", withExtension: nil) else { return }

        let fm = FileManager.default

        // Copy MCP tools (Python server + config)
        let mcpToolsSrc = templateDir.appendingPathComponent("mcp_tools.py")
        let mcpToolsDst = workspace.appendingPathComponent("mcp_tools.py")
        if !fm.fileExists(atPath: mcpToolsDst.path) {
            try? fm.copyItem(at: mcpToolsSrc, to: mcpToolsDst)
        }

        // Claude + Kimi read MCP config from .mcp.json
        let mcpConfigSrc = templateDir.appendingPathComponent("mcp.json")
        let mcpConfigDst = workspace.appendingPathComponent(".mcp.json")
        if !fm.fileExists(atPath: mcpConfigDst.path) {
            try? fm.copyItem(at: mcpConfigSrc, to: mcpConfigDst)
        }

        // Gemini CLI reads MCP config from .gemini/settings.json
        let geminiDir = workspace.appendingPathComponent(".gemini")
        let geminiSettingsDst = geminiDir.appendingPathComponent("settings.json")
        if !fm.fileExists(atPath: geminiSettingsDst.path) {
            try? fm.createDirectory(at: geminiDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: mcpConfigSrc, to: geminiSettingsDst)
        }

        // Create skills directory
        let skillsDst = workspace.appendingPathComponent("skills")
        try? fm.createDirectory(at: skillsDst, withIntermediateDirectories: true)

        // Copy role-specific skill file → always written as skills/solo.md so BossSystemPrompt reads it
        let skillFileName: String
        switch role {
        case .solo:     skillFileName = "solo.md"
        case .research: skillFileName = "research-only.md"
        case .builder:  skillFileName = "builder-only.md"
        }

        let skillSrc = templateDir.appendingPathComponent("skills/\(skillFileName)")
        let skillDst = skillsDst.appendingPathComponent("solo.md")
        if !fm.fileExists(atPath: skillDst.path) {
            try? fm.copyItem(at: skillSrc, to: skillDst)
        }

        // Load persistent memories first (from ~/Apex/memories/), fall back to template
        let memoryDst = skillsDst.appendingPathComponent("memory.md")
        loadMemories(to: workspace, role: role)

        if !fm.fileExists(atPath: memoryDst.path) {
            // No persistent memory — copy template as starting point
            let memoryFileName: String
            switch role {
            case .research: memoryFileName = "memory-research.md"
            case .builder, .solo: memoryFileName = "memory-build.md"
            }
            let memorySrc = templateDir.appendingPathComponent("skills/\(memoryFileName)")
            if fm.fileExists(atPath: memorySrc.path) {
                try? fm.copyItem(at: memorySrc, to: memoryDst)
            }
        }

        // Generate dynamic checklist based on config
        let checklistDst = workspace.appendingPathComponent("checklist.md")
        if !fm.fileExists(atPath: checklistDst.path) {
            let checklistContent = generateChecklist(role: role)
            try? checklistContent.write(to: checklistDst, atomically: true, encoding: .utf8)
        }

        // Copy .env with API keys from ~/Apex/.env
        let envSrc = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Apex/.env")
        let envDst = workspace.appendingPathComponent(".env")
        if fm.fileExists(atPath: envSrc.path) && !fm.fileExists(atPath: envDst.path) {
            try? fm.copyItem(at: envSrc, to: envDst)
        }
    }

    // MARK: - Dynamic Checklist

    private func generateChecklist(role: WorkspaceRole) -> String {
        let c = buildConfig

        // Research step description
        var researchSteps: [String] = []
        if c.scrapeCompanySite { researchSteps.append("visit site") }
        if c.webSearchCompany { researchSteps.append("web search") }
        if c.findInspirationSites {
            researchSteps.append("find \(c.inspirationSiteCount) inspiration sites + \(c.inspirationSiteCount) competitors")
        }
        let researchDesc = researchSteps.isEmpty
            ? "Write research.md"
            : researchSteps.joined(separator: " + ") + ", write research.md"

        // Build step description
        var buildParts: [String] = []
        if let img = imageInstruction { buildParts.append(img.lowercased()) }
        buildParts.append("one screen, 100vh, no scroll")
        if !c.webSearchDuringLayout { buildParts.append("no web search") }
        if pendingInspirationImage != nil { buildParts.append("see inspiration.jpg") }
        let buildDesc = "Build proposal/index.html (\(buildParts.joined(separator: ", ")))"

        switch role {
        case .research:
            return """
            # Research Checklist

            - [ ] UNDERSTAND — Extract info from user message, write brief.md
            - [ ] RESEARCH — \(researchDesc)
            """

        case .builder:
            return """
            # Builder Checklist

            - [x] UNDERSTAND — (done by research agent)
            - [x] RESEARCH — (done by research agent)
            - [ ] VECTOR — Choose your own unique direction to push the brand
            - [ ] BUILD — \(buildDesc)
            - [ ] REVIEW — Verify all images exist, fix missing
            - [ ] REFINE — Improve based on feedback
            """

        case .solo:
            let understandDesc = c.skipClarification
                ? "Extract info from user message, write brief.md"
                : "Ask questions, write brief.md"

            return """
            # Checklist

            - [ ] UNDERSTAND — \(understandDesc)
            - [ ] RESEARCH — \(researchDesc)
            - [ ] VECTOR — Choose one direction to push the brand, write to research.md
            - [ ] BUILD — \(buildDesc)
            - [ ] REVIEW — Verify all images exist, fix missing
            - [ ] REFINE — Improve based on feedback
            """
        }
    }

    // MARK: - Memory Persistence

    private static var memoriesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Apex/memories")
    }

    /// Persistent memory filename for a given role
    private func memoryPersistName(for role: WorkspaceRole) -> String {
        switch role {
        case .research: return "memory-research.md"
        case .builder, .solo: return "memory-build.md"
        }
    }

    /// Load persistent memory into workspace as skills/memory.md
    private func loadMemories(to workspace: URL, role: WorkspaceRole = .solo) {
        let fm = FileManager.default
        let memDir = Self.memoriesDir
        let src = memDir.appendingPathComponent(memoryPersistName(for: role))
        let dst = workspace.appendingPathComponent("skills/memory.md")

        guard fm.fileExists(atPath: src.path) else { return }
        guard !fm.fileExists(atPath: dst.path) else { return }
        try? fm.copyItem(at: src, to: dst)
    }

    /// Save workspace memory.md back to persistent storage
    func saveMemories(from boss: BossInstance) {
        guard let workspace = boss.workspace else { return }
        let fm = FileManager.default
        let memDir = Self.memoriesDir

        try? fm.createDirectory(at: memDir, withIntermediateDirectories: true)

        let src = workspace.appendingPathComponent("skills/memory.md")
        guard fm.fileExists(atPath: src.path) else { return }

        // Determine role from boss id
        let role: WorkspaceRole = boss.id == "research" ? .research : (researchBoss != nil ? .builder : .solo)
        let dst = memDir.appendingPathComponent(memoryPersistName(for: role))
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: src, to: dst)
    }

    // MARK: - Git

    private func initGitRepo(at workspace: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = workspace
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        // Set local git config (ensures commits work without global config)
        let configName = Process()
        configName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configName.arguments = ["config", "user.name", "Apex"]
        configName.currentDirectoryURL = workspace
        configName.standardOutput = FileHandle.nullDevice
        configName.standardError = FileHandle.nullDevice
        try? configName.run()
        configName.waitUntilExit()

        let configEmail = Process()
        configEmail.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configEmail.arguments = ["config", "user.email", "apex@local"]
        configEmail.currentDirectoryURL = workspace
        configEmail.standardOutput = FileHandle.nullDevice
        configEmail.standardError = FileHandle.nullDevice
        try? configEmail.run()
        configEmail.waitUntilExit()
    }

    /// Create an initial commit so every workspace has at least v1
    private func initialCommit(at workspace: URL) {
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "-A"]
        addProcess.currentDirectoryURL = workspace
        addProcess.standardOutput = FileHandle.nullDevice
        addProcess.standardError = FileHandle.nullDevice
        try? addProcess.run()
        addProcess.waitUntilExit()

        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", "Setup workspace"]
        commitProcess.currentDirectoryURL = workspace
        commitProcess.standardOutput = FileHandle.nullDevice
        commitProcess.standardError = FileHandle.nullDevice
        try? commitProcess.run()
        commitProcess.waitUntilExit()
    }

    // MARK: - Project Linking

    private func linkWorkspaceAsProject(boss: BossInstance) {
        guard let projectName = boss.projectName else { return }
        let ws = LocalWorkspaceService.shared

        guard ws.findMainHTML(project: projectName) != nil else { return }

        let isFirst = !projectLinked
        projectLinked = true

        let projectMsg = ChatMessage(
            role: .assistant,
            content: "Preview ready — check the Design view.",
            timestamp: Date()
        )
        boss.messages.append(projectMsg)

        Task {
            let localId = "local:\(projectName)"
            await delegate?.loadProject(id: localId)
            // Only auto-select the first builder to finish — others appear in sidebar without stealing focus
            if isFirst {
                delegate?.setSelectedProjectId(localId)
            }
            delegate?.refreshLocalProjects()
        }
    }

    private func reloadLocalPreview(boss: BossInstance) {
        guard let projectName = boss.projectName else { return }

        // Always refresh sidebar so new layouts appear
        delegate?.refreshLocalProjects()

        // Only reload the preview if this boss is the currently selected project
        let localId = "local:\(projectName)"
        guard delegate?.selectedProjectId == localId else { return }

        let ws = LocalWorkspaceService.shared

        // Refresh file listing for code mode sidebar
        let files = ws.listFiles(project: projectName)
        delegate?.setLocalFiles(files)

        // Refresh all HTML pages
        let htmlFiles = files.filter { !$0.isDirectory && $0.path.hasSuffix(".html") }
        var newPages: [Page] = []
        for file in htmlFiles {
            let filePath = ws.projectPath(projectName).appendingPathComponent(file.path)
            if let html = try? String(contentsOf: filePath, encoding: .utf8) {
                let page = Page.local(
                    id: "local-page-\(projectName)/\(file.path)",
                    name: file.name,
                    html: html
                )
                newPages.append(page)
            }
        }

        let previousSelection = delegate?.selectedPageId
        delegate?.setPages(newPages)

        if newPages.contains(where: { $0.id == previousSelection }) {
            // Keep current selection
        } else if let mainFile = ws.findMainHTML(project: projectName) {
            delegate?.setSelectedPageId("local-page-\(projectName)/\(mainFile)")
        } else {
            delegate?.setSelectedPageId(newPages.first?.id)
        }

        delegate?.setLocalPreviewURL(boss.workspace)
        delegate?.refreshPreview()
    }

    // MARK: - Version Tracking (Git)

    /// Commit current workspace state as a new version
    private func commitVersion(boss: BossInstance, message: String) async {
        guard let projectName = boss.projectName else { return }
        let ws = LocalWorkspaceService.shared
        _ = try? await ws.gitCommit(project: projectName, message: message)
    }

    // MARK: - Deployment Output Parsing

    private func extractServerProjectId(from text: String) -> String? {
        let uuidPattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        if let range = text.range(of: "Server project: (\(uuidPattern))", options: .regularExpression) {
            let match = String(text[range])
            if let uuidRange = match.range(of: uuidPattern, options: .regularExpression) {
                return String(match[uuidRange])
            }
        }
        if let range = text.range(of: "\"project_id\":\\s*\"(\(uuidPattern))\"", options: .regularExpression) {
            let match = String(text[range])
            if let uuidRange = match.range(of: uuidPattern, options: .regularExpression) {
                return String(match[uuidRange])
            }
        }
        return nil
    }

    private func linkServerProject(_ projectId: String) {
        projectLinked = true

        if let boss = selectedBoss {
            let deployMsg = ChatMessage(
                role: .assistant,
                content: "Deployed to server — loading preview...",
                timestamp: Date()
            )
            boss.messages.append(deployMsg)
        }

        Task {
            await delegate?.loadProject(id: projectId)
            delegate?.setSelectedProjectId(projectId)
        }
    }
}
