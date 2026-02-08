import SwiftUI

extension BossCoordinator {
    // MARK: - Two-Phase Flow

    func startTwoPhaseFlow(_ text: String, setLoading: @escaping (Bool) -> Void) {
        guard let research = researchBoss else { return }

        phase = .researching
        selectedBossId = research.id

        // Fully clear the previous project so the sidebar falls back to the project list
        delegate?.clearCurrentProject()

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
                    guard let boss else { return }

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
    func saveInspirationImage(to workspace: URL) {
        guard let image = pendingInspirationImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

        let dst = workspace.appendingPathComponent("inspiration.jpg")
        try? jpegData.write(to: dst)
    }

    // MARK: - Opus Design Flow

    /// Entry point for the Opus Design flow — Opus researches + defines 3 designs, then 3 Kimi build them
    func startOpusDesignFlow(_ text: String, setLoading: @escaping (Bool) -> Void) {
        guard let research = researchBoss else { return }

        phase = .researching
        selectedBossId = research.id

        delegate?.clearCurrentProject()

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
            ? "Write brief.md from the user's information, then proceed to RESEARCH, then DESIGN."
            : researchInstructions.joined(separator: "\n") + "\nAfter RESEARCH, proceed to DESIGN — define 3 distinct design alternatives in designs.md."

        let researchPrompt = """
        This is the complete project brief from the user.

        \(instructions)

        User's request:
        \(text)
        """

        // Pre-create builder workspaces while research runs
        for boss in bosses where boss.workspace == nil {
            boss.workspace = createWorkspace(for: boss, role: .builder)
        }

        delegate?.refreshLocalProjects()

        Task {
            // Phase 1: Research + Design (Opus)
            await awaitableSend(research, text: researchPrompt, role: .researchDesign, setLoading: setLoading)

            // Phase 2: Build (3x Kimi with assigned designs)
            await startDesignBuildPhase()
        }
    }

    /// Start the design build phase — parse designs.md and send each Kimi its assigned design
    private func startDesignBuildPhase() async {
        guard let research = researchBoss, let researchWorkspace = research.workspace else { return }

        phase = .building
        selectedBossId = bosses.first?.id

        // Parse the 3 design alternatives from designs.md
        let designsURL = researchWorkspace.appendingPathComponent("designs.md")
        let designs = parseDesigns(from: designsURL)

        // Create workspaces and copy research + assigned wireframe for each builder
        for (i, boss) in bosses.enumerated() {
            if boss.workspace == nil {
                boss.workspace = createWorkspace(for: boss, role: .builder)
            }
            guard let bossWorkspace = boss.workspace else { continue }
            copyResearchAndDesignFiles(from: researchWorkspace, to: bossWorkspace, builderIndex: i)
            saveInspirationImage(to: bossWorkspace)
        }

        // Send each builder its assigned design direction
        for (i, boss) in bosses.enumerated() {
            let designText = i < designs.count ? designs[i] : designs.last ?? "Follow brief.md and research.md to build a unique design proposal."

            var buildMessage = """
            Research and design direction are ready. Read brief.md and research.md for context.

            YOUR ASSIGNED DESIGN DIRECTION:
            \(designText)

            VISUAL REFERENCE: See images/wireframe.png for a wireframe mockup of this design. Match the layout, color blocks, and spatial hierarchy shown in the wireframe.

            Build this exact design — do NOT deviate from the direction above. Follow your checklist: start with BUILD (your vector is already defined above).
            """

            if let imgInst = imageInstruction {
                buildMessage += "\n\nImage approach: \(imgInst)"
            }
            if !buildConfig.webSearchDuringLayout {
                buildMessage += "\nDo NOT search the web while building — work only with the research files."
            }
            if pendingInspirationImage != nil {
                buildMessage += "\nSee inspiration.jpg in the workspace for visual reference."
            }

            sendToBoss(boss, text: buildMessage, setLoading: { _ in })
        }
    }

    /// Parse designs.md into individual design sections by splitting on `## Design` headers
    private func parseDesigns(from url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        // Split on lines starting with "## Design"
        let lines = content.components(separatedBy: "\n")
        var designs: [String] = []
        var currentDesign: [String] = []
        var inDesign = false

        for line in lines {
            if line.hasPrefix("## Design") {
                if inDesign && !currentDesign.isEmpty {
                    designs.append(currentDesign.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentDesign = [line]
                inDesign = true
            } else if inDesign {
                currentDesign.append(line)
            }
        }

        // Append the last design
        if inDesign && !currentDesign.isEmpty {
            designs.append(currentDesign.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Fallback: if we got fewer than 3, duplicate the last one
        if !designs.isEmpty {
            while designs.count < 3 {
                designs.append(designs.last!)
            }
        }

        return designs
    }

    /// Copy brief.md, research.md, designs.md, and only the assigned wireframe from research workspace to builder workspace
    private func copyResearchAndDesignFiles(from source: URL, to destination: URL, builderIndex: Int) {
        let fm = FileManager.default
        let filesToCopy = ["brief.md", "research.md", "designs.md"]

        for file in filesToCopy {
            let src = source.appendingPathComponent(file)
            let dst = destination.appendingPathComponent(file)
            guard fm.fileExists(atPath: src.path) else { continue }
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: src, to: dst)
        }

        // Create images directory in builder workspace
        let imagesDst = destination.appendingPathComponent("images")
        try? fm.createDirectory(at: imagesDst, withIntermediateDirectories: true)

        // Copy only the assigned wireframe, renamed to wireframe.png
        let wireframeSrc = source.appendingPathComponent("images/wireframe-\(builderIndex + 1).png")
        let wireframeDst = imagesDst.appendingPathComponent("wireframe.png")
        if fm.fileExists(atPath: wireframeSrc.path) {
            try? fm.removeItem(at: wireframeDst)
            try? fm.copyItem(at: wireframeSrc, to: wireframeDst)
        }
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

}
