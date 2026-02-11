import Foundation

/// Persistent memory across projects — builders accumulate learnings
///
/// Storage: ~/Forge/memories/
///   - memory-build.md     (builder agent learnings)
///
/// Flow: load persistent → inject into agent prompt → agent updates memory.md in project → save back to persistent
@MainActor
class MemoryService {
    private let memoriesDir: URL

    init() {
        self.memoriesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Forge/memories")
        ensureDirectory()
    }

    // MARK: - Load

    /// Load builder memory (accumulated design/code learnings)
    func loadBuilderMemory() -> String? {
        readFile("memory-build.md")
    }

    // MARK: - Save

    /// Save builder memory back to persistent storage
    func saveBuilderMemory(_ content: String) {
        writeFile("memory-build.md", content: content)
    }

    // MARK: - Project Integration

    /// Copy persistent memory into a project workspace so builders can read/update it
    func copyToProject(workspace: LocalWorkspaceService, projectName: String) {
        let content = loadBuilderMemory()
        guard let content, !content.isEmpty else {
            try? workspace.writeFile(project: projectName, path: "memory.md", content: Self.builderTemplate)
            return
        }
        try? workspace.writeFile(project: projectName, path: "memory.md", content: content)
    }

    /// Save memory from a project workspace back to persistent storage
    func saveFromProject(workspace: LocalWorkspaceService, projectName: String) {
        guard let content = try? workspace.readFile(project: projectName, path: "memory.md"),
              !content.isEmpty,
              content.count > 50 else { return }

        saveBuilderMemory(content)

        #if DEBUG
        print("[MemoryService] Saved builder memory from \(projectName) — \(content.count) chars")
        #endif
    }

    // MARK: - Private

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: memoriesDir, withIntermediateDirectories: true)
    }

    private func readFile(_ name: String) -> String? {
        let url = memoriesDir.appendingPathComponent(name)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func writeFile(_ name: String, content: String) {
        let url = memoriesDir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Templates

    static let builderTemplate = """
    # Memory — Builder

    Read before every project. Update with learnings after each project. Max ~20 items.

    ## Design
    - (no learnings yet)

    ## Images
    - (no learnings yet)

    ## Technical
    - (no learnings yet)
    """
}
