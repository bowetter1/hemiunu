import SwiftUI

extension BossCoordinator {
    // MARK: - Deployment Output Parsing

    func extractServerProjectId(from text: String) -> String? {
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

    func linkServerProject(_ projectId: String) {
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
