import SwiftUI

extension BossCoordinator {
    // MARK: - Version Tracking (Git)

    /// Commit current workspace state as a new version
    func commitVersion(boss: BossInstance, message: String) async {
        guard let projectName = boss.projectName else { return }
        let ws = LocalWorkspaceService.shared
        _ = try? await ws.gitCommit(project: projectName, message: message)
    }

}
