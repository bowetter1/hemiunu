import Foundation

/// Persistent memory across projects — builders and researchers accumulate learnings
///
/// Storage: ~/Forge/memories/
///   - memory-build.md     (builder agent learnings)
///   - memory-research.md  (research agent learnings)
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

    /// Load researcher memory (accumulated research learnings)
    func loadResearcherMemory() -> String? {
        readFile("memory-research.md")
    }

    // MARK: - Save

    /// Save builder memory back to persistent storage
    func saveBuilderMemory(_ content: String) {
        writeFile("memory-build.md", content: content)
    }

    /// Save researcher memory back to persistent storage
    func saveResearcherMemory(_ content: String) {
        writeFile("memory-research.md", content: content)
    }

    // MARK: - Project Integration

    /// Copy persistent memory into a project workspace so builders can read/update it
    func copyToProject(workspace: LocalWorkspaceService, projectName: String, role: Role) {
        let content = role == .builder ? loadBuilderMemory() : loadResearcherMemory()
        guard let content, !content.isEmpty else {
            // Write empty template if no memory exists yet
            let template = role == .builder ? Self.builderTemplate : Self.researcherTemplate
            try? workspace.writeFile(project: projectName, path: "memory.md", content: template)
            return
        }
        try? workspace.writeFile(project: projectName, path: "memory.md", content: content)
    }

    /// Save memory from a project workspace back to persistent storage
    func saveFromProject(workspace: LocalWorkspaceService, projectName: String, role: Role) {
        guard let content = try? workspace.readFile(project: projectName, path: "memory.md"),
              !content.isEmpty,
              content.count > 50 else { return } // Skip if empty/trivial

        if role == .builder {
            saveBuilderMemory(content)
        } else {
            saveResearcherMemory(content)
        }

        #if DEBUG
        print("[MemoryService] Saved \(role) memory from \(projectName) — \(content.count) chars")
        #endif
    }

    // MARK: - Types

    enum Role {
        case builder
        case researcher
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

    static let researcherTemplate = """
    # Memory — Researcher

    Read before every project. Update with learnings after each project. Max ~20 items.

    ## Research
    - (no learnings yet)

    ## Tools
    - (no learnings yet)

    ## Brands
    - (no learnings yet)
    """
}
