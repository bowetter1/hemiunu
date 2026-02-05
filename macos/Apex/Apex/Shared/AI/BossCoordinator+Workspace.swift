import SwiftUI

extension BossCoordinator {
    // MARK: - Workspace Creation

    func createWorkspace(for boss: BossInstance, role: WorkspaceRole = .solo) -> URL {
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
                try? name.write(to: nameFile, atomically: true, encoding: String.Encoding.utf8)
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

    /// Copy a required template file, logging on failure instead of silently swallowing errors.
    private func copyRequired(_ src: URL, to dst: URL, label: String) {
        do {
            try FileManager.default.copyItem(at: src, to: dst)
        } catch {
            print("[Workspace] FAILED to copy \(label): \(error.localizedDescription)")
        }
    }

    /// Copy templates from app bundle into the workspace, using role-specific skill and checklist files
    private func copyTemplates(to workspace: URL, role: WorkspaceRole = .solo) {
        guard let templateDir = Bundle.main.url(forResource: "boss-templates", withExtension: nil) else { return }

        let fm = FileManager.default

        // Copy MCP tools (Python server + config) — critical for agent operation
        let mcpToolsSrc = templateDir.appendingPathComponent("mcp_tools.py")
        let mcpToolsDst = workspace.appendingPathComponent("mcp_tools.py")
        if !fm.fileExists(atPath: mcpToolsDst.path) {
            copyRequired(mcpToolsSrc, to: mcpToolsDst, label: "mcp_tools.py")
        }

        // Claude + Kimi read MCP config from .mcp.json — critical
        let mcpConfigSrc = templateDir.appendingPathComponent("mcp.json")
        let mcpConfigDst = workspace.appendingPathComponent(".mcp.json")
        if !fm.fileExists(atPath: mcpConfigDst.path) {
            copyRequired(mcpConfigSrc, to: mcpConfigDst, label: ".mcp.json")
        }

        // Gemini CLI reads MCP config from .gemini/settings.json — critical
        let geminiDir = workspace.appendingPathComponent(".gemini")
        let geminiSettingsDst = geminiDir.appendingPathComponent("settings.json")
        if !fm.fileExists(atPath: geminiSettingsDst.path) {
            try? fm.createDirectory(at: geminiDir, withIntermediateDirectories: true)
            copyRequired(mcpConfigSrc, to: geminiSettingsDst, label: "gemini settings.json")
        }

        // Create skills directory
        let skillsDst = workspace.appendingPathComponent("skills")
        try? fm.createDirectory(at: skillsDst, withIntermediateDirectories: true)

        // Copy role-specific skill file — critical for agent behavior
        let skillFileName: String
        switch role {
        case .solo:     skillFileName = "solo.md"
        case .research: skillFileName = "research-only.md"
        case .builder:  skillFileName = "builder-only.md"
        }

        let skillSrc = templateDir.appendingPathComponent("skills/\(skillFileName)")
        let skillDst = skillsDst.appendingPathComponent("solo.md")
        if !fm.fileExists(atPath: skillDst.path) {
            copyRequired(skillSrc, to: skillDst, label: "skill file (\(skillFileName))")
        }

        // Load persistent memories first (from ~/Apex/memories/), fall back to template
        let memoryDst = skillsDst.appendingPathComponent("memory.md")
        loadMemories(to: workspace, role: role)

        if !fm.fileExists(atPath: memoryDst.path) {
            // No persistent memory — copy template as starting point (non-critical)
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

        // Generate dynamic checklist — critical for agent workflow
        let checklistDst = workspace.appendingPathComponent("checklist.md")
        if !fm.fileExists(atPath: checklistDst.path) {
            let checklistContent = generateChecklist(role: role)
            do {
                try checklistContent.write(to: checklistDst, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                print("[Workspace] FAILED to write checklist.md: \(error.localizedDescription)")
            }
        }

        // Copy .env with API keys from ~/Apex/.env — critical for API access
        let envSrc = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Apex/.env")
        let envDst = workspace.appendingPathComponent(".env")
        if fm.fileExists(atPath: envSrc.path) && !fm.fileExists(atPath: envDst.path) {
            copyRequired(envSrc, to: envDst, label: ".env")
        }
    }

}
