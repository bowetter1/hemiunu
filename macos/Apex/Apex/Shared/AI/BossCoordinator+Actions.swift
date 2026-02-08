import SwiftUI

extension BossCoordinator {
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

    /// Activate Opus Design flow: 1 Claude research boss + 3 Kimi builders
    func activateOpusDesign() {
        if isActive { resetSession() }
        isActive = true
        researchBoss = BossInstance(id: "research", agent: .claude)
        bosses = (0..<3).map { BossInstance(id: "boss-\($0)", agent: .kimi) }
        phase = .idle
        selectedBossId = researchBoss?.id
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
                delegate?.clearCurrentProject()
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

        // If we already have an active boss for this exact workspace, keep it (preserves session)
        let bossId = (projectName as NSString).lastPathComponent
        if isActive, let existing = bosses.first(where: { $0.id == bossId && $0.workspace == workspaceURL }) {
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
        let expectedWorkspace = LocalWorkspaceService.shared.projectPath(name)

        if let research = researchBoss, research.id == bossId,
           research.workspace == expectedWorkspace {
            selectedBossId = research.id
        } else if bosses.contains(where: { $0.id == bossId && $0.workspace == expectedWorkspace }) {
            selectedBossId = bossId
        } else {
            // No active boss for this workspace — resume it (loads workspace + messages)
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

}
