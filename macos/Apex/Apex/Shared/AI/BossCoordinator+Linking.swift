import SwiftUI

extension BossCoordinator {
    // MARK: - Project Linking

    func linkWorkspaceAsProject(boss: BossInstance) {
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

    func reloadLocalPreview(boss: BossInstance) {
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

        // Refresh pages (research artifacts at root are excluded)
        let newPages = ws.loadPages(project: projectName)

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

}
