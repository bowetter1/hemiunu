import SwiftUI

/// CodeViewModel — owns file tree state and code editing logic
@MainActor
@Observable
class CodeViewModel {
    var files: [FileTreeNode] = []
    var selectedFilePath: String?
    var currentFileContent: String = ""
    var isLoadingFiles = false
    var isLoadingContent = false
    var isSaving = false
    var errorMessage: String?
    var fileMetrics: [CodeFileMetric] = []
    var architectureViolations: [ArchitectureViolation] = []
    var layerDependencies: [LayerDependency] = []
    var flowHighlights: [String] = []
    var changedFiles: [String] = []
    var todoCount: Int = 0
    var totalFileCount: Int = 0
    var totalDirectoryCount: Int = 0
    var totalSourceLines: Int = 0
    var fileTypeMetrics: [FileTypeMetric] = []
    var detectedDatabases: [String] = []
    var dbMigrationCount: Int = 0
    var dbSchemaCount: Int = 0
    var dbRiskFlags: [String] = []
    var architectureModules: [ArchitectureModuleMetric] = []
    var architectureLinks: [ArchitectureLinkMetric] = []
    var flowMapEntries: [FlowMapEntry] = []

    private let appState: AppState
    var workspace: LocalWorkspaceService { appState.workspace }
    let codeExtensions: Set<String> = ["py", "js", "jsx", "ts", "tsx", "swift", "css", "scss", "html"]
    let largeFileLineThreshold = 300

    init(appState: AppState) {
        self.appState = appState
    }

    var largeFiles: [CodeFileMetric] {
        fileMetrics.filter { $0.lines >= largeFileLineThreshold }
    }

    var largestFile: CodeFileMetric? {
        fileMetrics.max {
            if $0.lines == $1.lines { return $0.path > $1.path }
            return $0.lines < $1.lines
        }
    }

    var healthScore: Int {
        let largePenalty = min(largeFiles.count * 5, 35)
        let violationPenalty = min(architectureViolations.count * 10, 45)
        let todoPenalty = min(max(todoCount - 8, 0), 10)
        let score = 100 - largePenalty - violationPenalty - todoPenalty
        return max(0, min(score, 100))
    }

    var currentProjectId: String? {
        appState.currentProject?.id
    }

    private var localProjectName: String? {
        guard let id = currentProjectId else { return nil }
        return appState.localProjectName(from: id)
    }

    func loadFiles() {
        guard currentProjectId != nil else { return }
        if let localName = localProjectName {
            loadLocalFiles(project: localName)
        }
    }

    private func loadLocalFiles(project: String) {
        isLoadingFiles = true
        let localFiles = workspace.listFiles(project: project)
            .filter { !$0.path.hasPrefix(".") && !$0.path.contains("/.") }
            .filter { !$0.path.hasPrefix("node_modules") && !$0.path.hasPrefix("skills") }
        files = buildFileTree(from: localFiles)
        analyzeProject(project: project, localFiles: localFiles)
        Task { [weak self] in
            await self?.refreshGitChanges(project: project)
        }
        isLoadingFiles = false
    }

    func loadFileContent(_ path: String) {
        if let localName = localProjectName {
            loadLocalFileContent(project: localName, path: path)
        }
    }

    private func loadLocalFileContent(project: String, path: String) {
        isLoadingContent = true
        do {
            currentFileContent = try workspace.readFile(project: project, path: path)
        } catch {
            currentFileContent = ""
            errorMessage = error.localizedDescription
        }
        isLoadingContent = false
    }

    func saveCurrentFile() {
        guard let path = selectedFilePath else { return }
        if let localName = localProjectName {
            saveLocalFile(project: localName, path: path)
        }
    }

    private func saveLocalFile(project: String, path: String) {
        isSaving = true
        do {
            try workspace.writeFile(project: project, path: path, content: currentFileContent)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func buildFileTree(from localFiles: [LocalFileInfo]) -> [FileTreeNode] {
        var root: [String: FileTreeNode] = [:]
        var dirNodes: [String: FileTreeNode] = [:]
        let sorted = localFiles.sorted { $0.path < $1.path }

        for file in sorted where !file.isDirectory {
            let components = file.path.components(separatedBy: "/")
            for i in 0..<(components.count - 1) {
                let dirPath = components[0...i].joined(separator: "/")
                if dirNodes[dirPath] == nil {
                    dirNodes[dirPath] = FileTreeNode(
                        id: dirPath, name: components[i], path: dirPath,
                        isDirectory: true, size: 0, fileType: nil, children: []
                    )
                }
            }
            let node = FileTreeNode(
                id: file.path, name: file.name, path: file.path,
                isDirectory: false, size: file.size,
                fileType: (file.name as NSString).pathExtension, children: []
            )
            if components.count > 1 {
                let parentPath = components[0..<(components.count - 1)].joined(separator: "/")
                dirNodes[parentPath]?.children.append(node)
            } else {
                root[file.path] = node
            }
        }

        let sortedDirs = dirNodes.keys.sorted().reversed()
        for dirPath in sortedDirs {
            guard let dirNode = dirNodes[dirPath] else { continue }
            let components = dirPath.components(separatedBy: "/")
            if components.count > 1 {
                let parentPath = components[0..<(components.count - 1)].joined(separator: "/")
                dirNodes[parentPath]?.children.append(dirNode)
            } else {
                root[dirPath] = dirNode
            }
        }
        return root.values.sorted { $0.name < $1.name }
    }

}
