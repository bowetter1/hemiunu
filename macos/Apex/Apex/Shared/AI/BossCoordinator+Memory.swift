import SwiftUI

extension BossCoordinator {
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
    func loadMemories(to workspace: URL, role: WorkspaceRole = .solo) {
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

}
