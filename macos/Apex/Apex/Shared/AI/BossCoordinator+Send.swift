import SwiftUI

extension BossCoordinator {
    // MARK: - Private: Send

    func sendToBoss(_ boss: BossInstance, text: String, setLoading: @escaping (Bool) -> Void) {
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
                delegate?.refreshLocalProjects()
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

}
