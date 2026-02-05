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
