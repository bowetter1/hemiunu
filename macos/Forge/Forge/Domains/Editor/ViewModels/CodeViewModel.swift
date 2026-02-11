import SwiftUI

struct CodeFileMetric: Identifiable {
    let path: String
    let layer: String
    let lines: Int
    let bytes: Int

    var id: String { path }
}

struct ArchitectureViolation: Identifiable {
    let filePath: String
    let importedModule: String
    let rule: String

    var id: String { "\(filePath)|\(importedModule)|\(rule)" }
}

struct LayerDependency: Identifiable {
    let fromLayer: String
    let toLayer: String
    let count: Int

    var id: String { "\(fromLayer)->\(toLayer)" }
}

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

    private let appState: AppState
    private var workspace: LocalWorkspaceService { appState.workspace }
    private let codeExtensions: Set<String> = ["py", "js", "jsx", "ts", "tsx", "swift", "css", "scss", "html"]
    let largeFileLineThreshold = 300

    init(appState: AppState) {
        self.appState = appState
    }

    var largeFiles: [CodeFileMetric] {
        fileMetrics.filter { $0.lines >= largeFileLineThreshold }
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

    // MARK: - Project Analysis

    private func analyzeProject(project: String, localFiles: [LocalFileInfo]) {
        var nextMetrics: [CodeFileMetric] = []
        var nextViolations: [ArchitectureViolation] = []
        var dependencyCounts: [String: Int] = [:]
        var nextFlowHighlights: [String] = []
        var nextTodoCount = 0

        let sourceFiles = localFiles
            .filter { !$0.isDirectory }
            .filter { file in
                let ext = (file.path as NSString).pathExtension.lowercased()
                return codeExtensions.contains(ext)
            }

        for file in sourceFiles {
            guard let content = try? workspace.readFile(project: project, path: file.path) else { continue }

            nextTodoCount += countTodos(in: content)

            let lines = content.isEmpty ? 0 : content.components(separatedBy: .newlines).count
            let fileLayer = layer(forPath: file.path)
            nextMetrics.append(CodeFileMetric(path: file.path, layer: fileLayer, lines: lines, bytes: file.size))

            let ext = (file.path as NSString).pathExtension.lowercased()
            if ext == "py" {
                let imports = parsePythonImports(content: content)
                for module in imports {
                    let importedLayer = layer(forModule: module)
                    if importedLayer != "external" && importedLayer != fileLayer {
                        dependencyCounts["\(fileLayer)->\(importedLayer)", default: 0] += 1
                    }

                    if fileLayer == "domain", ["app", "infra", "services"].contains(importedLayer) {
                        nextViolations.append(ArchitectureViolation(
                            filePath: file.path,
                            importedModule: module,
                            rule: "Domain must not depend on app/infra/services"
                        ))
                    }

                    if fileLayer == "services", ["app", "infra"].contains(importedLayer) {
                        nextViolations.append(ArchitectureViolation(
                            filePath: file.path,
                            importedModule: module,
                            rule: "Services should not depend on app/infra"
                        ))
                    }
                }

                if file.path.hasPrefix("app/api/") {
                    let flow = summarizeFlow(apiFilePath: file.path, imports: imports)
                    if !flow.isEmpty {
                        nextFlowHighlights.append(flow)
                    }
                }
            }
        }

        fileMetrics = nextMetrics.sorted {
            if $0.lines == $1.lines { return $0.path < $1.path }
            return $0.lines > $1.lines
        }
        architectureViolations = nextViolations.sorted { $0.filePath < $1.filePath }
        flowHighlights = nextFlowHighlights.sorted()
        todoCount = nextTodoCount
        layerDependencies = dependencyCounts
            .map { key, count in
                let parts = key.components(separatedBy: "->")
                let from = parts.first ?? "unknown"
                let to = parts.count > 1 ? parts[1] : "unknown"
                return LayerDependency(fromLayer: from, toLayer: to, count: count)
            }
            .sorted {
                if $0.count == $1.count { return $0.id < $1.id }
                return $0.count > $1.count
            }
    }

    private func refreshGitChanges(project: String) async {
        do {
            let result = try await workspace.gitPorcelainStatus(project: project)
            changedFiles = parseGitPorcelain(result.output)
        } catch {
            changedFiles = []
        }
    }

    private func layer(forPath path: String) -> String {
        if path.hasPrefix("app/") { return "app" }
        if path.hasPrefix("domain/") { return "domain" }
        if path.hasPrefix("services/") { return "services" }
        if path.hasPrefix("infra/") { return "infra" }
        if path.hasPrefix("web/") { return "web" }
        if path.hasPrefix("tests/") { return "tests" }
        if path.hasPrefix("scripts/") { return "scripts" }
        if path.hasPrefix("docs/") { return "docs" }
        return "other"
    }

    private func layer(forModule module: String) -> String {
        let root = module.components(separatedBy: ".").first ?? module
        switch root {
        case "app", "domain", "services", "infra", "web":
            return root
        default:
            return "external"
        }
    }

    private func parsePythonImports(content: String) -> [String] {
        var modules: Set<String> = []

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") || line.isEmpty { continue }

            if line.hasPrefix("from ") {
                let rest = String(line.dropFirst(5))
                if let module = rest.components(separatedBy: .whitespaces).first,
                   !module.isEmpty,
                   !module.hasPrefix(".") {
                    modules.insert(module)
                }
                continue
            }

            if line.hasPrefix("import ") {
                let rest = String(line.dropFirst(7))
                let chunks = rest.components(separatedBy: ",")
                for chunk in chunks {
                    let cleaned = chunk.trimmingCharacters(in: .whitespaces)
                    if let module = cleaned.components(separatedBy: .whitespaces).first,
                       !module.isEmpty {
                        modules.insert(module)
                    }
                }
            }
        }

        return modules.sorted()
    }

    private func summarizeFlow(apiFilePath: String, imports: [String]) -> String {
        let fileName = (apiFilePath as NSString).lastPathComponent
        let services = imports.filter { $0.hasPrefix("services.") }.map { shortModule($0) }.sorted()
        let domains = imports.filter { $0.hasPrefix("domain.") }.map { shortModule($0) }.sorted()
        let infra = imports.filter { $0.hasPrefix("infra.") }.map { shortModule($0) }.sorted()

        if services.isEmpty && domains.isEmpty && infra.isEmpty {
            return ""
        }

        var parts: [String] = [fileName]
        if !services.isEmpty { parts.append("services: " + services.joined(separator: ", ")) }
        if !domains.isEmpty { parts.append("domain: " + domains.joined(separator: ", ")) }
        if !infra.isEmpty { parts.append("infra: " + infra.joined(separator: ", ")) }
        return parts.joined(separator: " -> ")
    }

    private func shortModule(_ module: String) -> String {
        module.components(separatedBy: ".").last ?? module
    }

    private func countTodos(in content: String) -> Int {
        content.components(separatedBy: .newlines).reduce(0) { partial, rawLine in
            let line = rawLine.lowercased()
            if line.contains("todo") || line.contains("fixme") {
                return partial + 1
            }
            return partial
        }
    }

    private func parseGitPorcelain(_ output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                if line.count <= 3 { return nil }
                let path = String(line.dropFirst(3))
                if path.isEmpty { return nil }
                return path
            }
    }
}
