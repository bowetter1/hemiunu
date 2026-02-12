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

struct FileTypeMetric: Identifiable {
    let extensionName: String
    let count: Int
    let totalBytes: Int

    var id: String { extensionName }
    var displayName: String {
        extensionName == "noext" ? "(no ext)" : ".\(extensionName)"
    }
}

struct ArchitectureModuleMetric: Identifiable {
    let module: String
    let fileCount: Int
    let lines: Int

    var id: String { module }
}

struct ArchitectureLinkMetric: Identifiable {
    let fromModule: String
    let toModule: String
    let count: Int

    var id: String { "\(fromModule)->\(toModule)" }
}

struct FlowMapEntry: Identifiable {
    let filePath: String
    let method: String
    let endpoint: String
    let chain: String

    var id: String { "\(method)|\(endpoint)|\(filePath)" }
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
    private var workspace: LocalWorkspaceService { appState.workspace }
    private let codeExtensions: Set<String> = ["py", "js", "jsx", "ts", "tsx", "swift", "css", "scss", "html"]
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

    // MARK: - Project Analysis

    private func analyzeProject(project: String, localFiles: [LocalFileInfo]) {
        var nextMetrics: [CodeFileMetric] = []
        var nextViolations: [ArchitectureViolation] = []
        var dependencyCounts: [String: Int] = [:]
        var nextFlowHighlights: [String] = []
        var nextFlowEntries: [FlowMapEntry] = []
        var nextTodoCount = 0
        var fileTypeCounts: [String: (count: Int, bytes: Int)] = [:]
        var moduleStats: [String: (files: Int, lines: Int)] = [:]
        var moduleLinkCounts: [String: Int] = [:]

        let nonDirectoryFiles = localFiles.filter { !$0.isDirectory }
        totalFileCount = nonDirectoryFiles.count
        totalDirectoryCount = localFiles.filter(\.isDirectory).count

        for file in nonDirectoryFiles {
            let ext = (file.path as NSString).pathExtension.lowercased()
            let key = ext.isEmpty ? "noext" : ext
            var value = fileTypeCounts[key] ?? (count: 0, bytes: 0)
            value.count += 1
            value.bytes += max(file.size, 0)
            fileTypeCounts[key] = value
        }

        let sourceFiles = nonDirectoryFiles
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
            let fileModule = module(forPath: file.path)
            var moduleValue = moduleStats[fileModule] ?? (files: 0, lines: 0)
            moduleValue.files += 1
            moduleValue.lines += lines
            moduleStats[fileModule] = moduleValue

            let ext = (file.path as NSString).pathExtension.lowercased()
            let internalImports = parseInternalImports(content: content, filePath: file.path, ext: ext)
            for importedPath in internalImports {
                let targetModule = module(forPath: importedPath)
                if targetModule.isEmpty || targetModule == fileModule { continue }
                moduleLinkCounts["\(fileModule)->\(targetModule)", default: 0] += 1
            }

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

            let flowEntries = buildFlowEntries(
                filePath: file.path,
                content: content,
                ext: ext,
                internalImports: internalImports
            )
            if !flowEntries.isEmpty {
                nextFlowEntries.append(contentsOf: flowEntries)
            }
        }

        fileMetrics = nextMetrics.sorted {
            if $0.lines == $1.lines { return $0.path < $1.path }
            return $0.lines > $1.lines
        }
        architectureViolations = nextViolations.sorted { $0.filePath < $1.filePath }
        todoCount = nextTodoCount
        totalSourceLines = nextMetrics.reduce(0) { $0 + $1.lines }
        fileTypeMetrics = fileTypeCounts
            .map { key, value in
                FileTypeMetric(extensionName: key, count: value.count, totalBytes: value.bytes)
            }
            .sorted {
                if $0.count == $1.count {
                    if $0.totalBytes == $1.totalBytes { return $0.extensionName < $1.extensionName }
                    return $0.totalBytes > $1.totalBytes
                }
                return $0.count > $1.count
            }
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
        architectureModules = moduleStats
            .map { key, value in
                ArchitectureModuleMetric(module: key, fileCount: value.files, lines: value.lines)
            }
            .sorted {
                if $0.lines == $1.lines {
                    if $0.fileCount == $1.fileCount { return $0.module < $1.module }
                    return $0.fileCount > $1.fileCount
                }
                return $0.lines > $1.lines
            }
        architectureLinks = moduleLinkCounts
            .map { key, count in
                let parts = key.components(separatedBy: "->")
                let from = parts.first ?? "unknown"
                let to = parts.count > 1 ? parts[1] : "unknown"
                return ArchitectureLinkMetric(fromModule: from, toModule: to, count: count)
            }
            .sorted {
                if $0.count == $1.count { return $0.id < $1.id }
                return $0.count > $1.count
            }
        flowMapEntries = nextFlowEntries.sorted {
            if $0.method == $1.method {
                if $0.endpoint == $1.endpoint { return $0.filePath < $1.filePath }
                return $0.endpoint < $1.endpoint
            }
            return $0.method < $1.method
        }
        if !flowMapEntries.isEmpty {
            nextFlowHighlights.append(contentsOf: flowMapEntries.prefix(8).map { entry in
                "\(entry.method) \(entry.endpoint) -> \(entry.chain)"
            })
        }
        flowHighlights = uniqueStrings(nextFlowHighlights)

        let dbSignals = detectDatabaseSignals(project: project, localFiles: nonDirectoryFiles)
        detectedDatabases = dbSignals.engines
        dbMigrationCount = dbSignals.migrationCount
        dbSchemaCount = dbSignals.schemaCount
        dbRiskFlags = dbSignals.risks
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

    private func parseInternalImports(content: String, filePath: String, ext: String) -> [String] {
        switch ext {
        case "py":
            return parsePythonImports(content: content)
                .map { $0.replacingOccurrences(of: ".", with: "/") }
                .filter { !$0.isEmpty }
        case "js", "jsx", "ts", "tsx":
            let modules = parseJavaScriptImports(content: content)
            var resolved: [String] = []
            for module in modules {
                let path = resolveJSImport(module, fromFilePath: filePath)
                if path.isEmpty { continue }
                resolved.append(path)
            }
            return uniqueStrings(resolved)
        default:
            return []
        }
    }

    private func parseJavaScriptImports(content: String) -> [String] {
        let patterns: [String] = [
            #"import\s+[^;\n]*?\s+from\s+["']([^"']+)["']"#,
            #"import\s+["']([^"']+)["']"#,
            #"require\s*\(\s*["']([^"']+)["']\s*\)"#
        ]

        var modules: [String] = []
        for pattern in patterns {
            modules.append(contentsOf: regexCapturedValues(pattern: pattern, in: content))
        }
        return uniqueStrings(modules)
    }

    private func regexCapturedValues(pattern: String, in content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        return regex.matches(in: content, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let valueRange = match.range(at: 1)
            guard valueRange.location != NSNotFound else { return nil }
            return nsContent.substring(with: valueRange).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func resolveJSImport(_ source: String, fromFilePath filePath: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        if trimmed.hasPrefix("./") || trimmed.hasPrefix("../") {
            let base = (filePath as NSString).deletingLastPathComponent
            let joined = (base as NSString).appendingPathComponent(trimmed)
            return stripKnownFileSuffix(from: (joined as NSString).standardizingPath)
        }

        if trimmed.hasPrefix("@/") || trimmed.hasPrefix("~/") {
            return stripKnownFileSuffix(from: String(trimmed.dropFirst(2)))
        }

        if trimmed.contains("/") {
            return stripKnownFileSuffix(from: trimmed)
        }

        return ""
    }

    private func stripKnownFileSuffix(from rawPath: String) -> String {
        var path = rawPath.replacingOccurrences(of: "\\", with: "/")
        while path.hasPrefix("./") {
            path.removeFirst(2)
        }

        let knownSuffixes = [".js", ".jsx", ".ts", ".tsx", ".py", ".swift", ".mjs", ".cjs"]
        for suffix in knownSuffixes where path.hasSuffix(suffix) {
            path = String(path.dropLast(suffix.count))
            break
        }

        if path.hasSuffix("/index") {
            path = String(path.dropLast("/index".count))
        }

        return path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func module(forPath path: String) -> String {
        let normalized = stripKnownFileSuffix(from: path.replacingOccurrences(of: "\\", with: "/"))
        var components = normalized.components(separatedBy: "/").filter { !$0.isEmpty }
        if components.count == 1, let first = components.first, first.contains(".") {
            components = first.components(separatedBy: ".").filter { !$0.isEmpty }
        }
        guard !components.isEmpty else { return "root" }

        let first = components[0]
        if first == "@" || first == "~" {
            if components.count >= 3 {
                return "\(components[1])/\(components[2])"
            }
            if components.count >= 2 {
                return components[1]
            }
            return "root"
        }

        if components.count >= 2 {
            return "\(components[0])/\(components[1])"
        }
        return first
    }

    private func buildFlowEntries(filePath: String, content: String, ext: String, internalImports: [String]) -> [FlowMapEntry] {
        let endpoints = parseEndpoints(content: content, filePath: filePath, ext: ext)
        guard !endpoints.isEmpty else { return [] }

        let services = compactModules(
            internalImports.filter {
                $0.contains("/service") || $0.hasPrefix("services/") || $0.hasPrefix("app/services/")
            }
        )
        let domains = compactModules(
            internalImports.filter {
                $0.hasPrefix("domain/") || $0.contains("/domain/")
            }
        )
        let data = compactModules(
            internalImports.filter {
                $0.hasPrefix("infra/")
                || $0.contains("/repository")
                || $0.contains("/repo")
                || $0.contains("/db")
                || $0.contains("/database")
                || $0.contains("/prisma")
            }
        )

        var chainParts: [String] = []
        if !services.isEmpty { chainParts.append("service: " + services.joined(separator: ", ")) }
        if !domains.isEmpty { chainParts.append("domain: " + domains.joined(separator: ", ")) }
        if !data.isEmpty { chainParts.append("data: " + data.joined(separator: ", ")) }
        let chain = chainParts.isEmpty ? "handler only" : chainParts.joined(separator: " -> ")

        return endpoints.map { endpoint in
            FlowMapEntry(
                filePath: filePath,
                method: endpoint.method,
                endpoint: endpoint.path,
                chain: chain
            )
        }
    }

    private func parseEndpoints(content: String, filePath: String, ext: String) -> [(method: String, path: String)] {
        var endpoints: [(method: String, path: String)] = []

        let pythonDecoratorPattern = #"@(router|app)\.(get|post|put|delete|patch)\s*\(\s*["']([^"']+)["']"#
        let expressPattern = #"(router|app)\.(get|post|put|delete|patch)\s*\(\s*["']([^"']+)["']"#

        if ["py", "js", "jsx", "ts", "tsx"].contains(ext) {
            for match in regexCapturedPairs(pattern: pythonDecoratorPattern, in: content) {
                endpoints.append((method: match.first.uppercased(), path: match.second))
            }
            for match in regexCapturedPairs(pattern: expressPattern, in: content) {
                endpoints.append((method: match.first.uppercased(), path: match.second))
            }
        }

        if endpoints.isEmpty, let inferredPath = inferEndpointPath(from: filePath, ext: ext) {
            let inferredMethod = inferMethodFromRouteFile(content: content)
            endpoints.append((method: inferredMethod, path: inferredPath))
        }

        return uniqueEndpointPairs(endpoints)
    }

    private func regexCapturedPairs(pattern: String, in content: String) -> [(first: String, second: String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        return regex.matches(in: content, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 3 else { return nil }
            let methodRange = match.range(at: 2)
            let pathRange = match.range(at: 3)
            guard methodRange.location != NSNotFound, pathRange.location != NSNotFound else { return nil }
            return (
                first: nsContent.substring(with: methodRange),
                second: nsContent.substring(with: pathRange)
            )
        }
    }

    private func inferEndpointPath(from filePath: String, ext: String) -> String? {
        let normalized = filePath.replacingOccurrences(of: "\\", with: "/")
        let noExt = stripKnownFileSuffix(from: normalized)

        if let apiRange = noExt.range(of: "/app/api/") {
            let pathPart = String(noExt[apiRange.upperBound...]).replacingOccurrences(of: "/route", with: "")
            return "/" + pathPart
        }
        if let pagesRange = noExt.range(of: "/pages/api/") {
            let pathPart = String(noExt[pagesRange.upperBound...]).replacingOccurrences(of: "/index", with: "")
            return "/api/" + pathPart
        }
        if noExt.hasPrefix("app/api/") {
            let pathPart = String(noExt.dropFirst("app/api/".count)).replacingOccurrences(of: "/route", with: "")
            return "/" + pathPart
        }
        if noExt.hasPrefix("api/") {
            return "/" + String(noExt.dropFirst("api/".count))
        }
        if noExt.hasPrefix("app/routes/") {
            return "/" + String(noExt.dropFirst("app/routes/".count))
        }

        let fileName = (noExt as NSString).lastPathComponent
        if ["route", "routes", "router", "handlers", "controller"].contains(fileName.lowercased()) {
            return "/" + (noExt as NSString).deletingLastPathComponent
        }

        if noExt.contains("/api/") || noExt.contains("/routes/") {
            if let range = noExt.range(of: "/api/") {
                let pathPart = String(noExt[range.upperBound...]).replacingOccurrences(of: "/route", with: "")
                return "/" + pathPart
            }
            if let range = noExt.range(of: "/routes/") {
                let pathPart = String(noExt[range.upperBound...]).replacingOccurrences(of: "/index", with: "")
                return "/" + pathPart
            }
        }

        return nil
    }

    private func inferMethodFromRouteFile(content: String) -> String {
        let upper = content.uppercased()
        for method in ["GET", "POST", "PUT", "PATCH", "DELETE"] {
            if upper.contains("FUNCTION \(method)") || upper.contains(".\(method.lowercased())(") || upper.contains("@\(method.lowercased())") {
                return method
            }
        }
        return "ANY"
    }

    private func compactModules(_ paths: [String]) -> [String] {
        let compact = paths.map { module(forPath: $0) }
        return uniqueStrings(compact).prefix(3).map { $0 }
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            if value.isEmpty || seen.contains(value) { continue }
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    private func uniqueEndpointPairs(_ values: [(method: String, path: String)]) -> [(method: String, path: String)] {
        var seen: Set<String> = []
        var result: [(method: String, path: String)] = []
        for value in values {
            let normalizedPath = value.path.hasPrefix("/") ? value.path : "/" + value.path
            let key = "\(value.method.uppercased()) \(normalizedPath)"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append((method: value.method.uppercased(), path: normalizedPath))
        }
        return result
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

    private func detectDatabaseSignals(project: String, localFiles: [LocalFileInfo]) -> (engines: [String], migrationCount: Int, schemaCount: Int, risks: [String]) {
        var engines: Set<String> = []
        var migrationCount = 0
        var schemaCount = 0
        var rawSQLFileCount = 0

        let sqlEngines: Set<String> = ["PostgreSQL", "MySQL", "SQLite"]

        for file in localFiles {
            let pathLower = file.path.lowercased()
            let ext = (file.path as NSString).pathExtension.lowercased()

            if pathLower.contains("/migrations/") || pathLower.hasPrefix("migrations/") {
                if ["sql", "py", "ts", "js", "rb"].contains(ext) {
                    migrationCount += 1
                }
            }

            if pathLower.hasSuffix("schema.prisma")
                || pathLower.hasSuffix("schema.sql")
                || pathLower.hasSuffix("db/schema.rb")
                || pathLower.hasSuffix("alembic.ini")
                || pathLower.contains("/alembic/versions/")
                || pathLower.contains("/prisma/migrations/") {
                schemaCount += 1
            }

            if ext == "sql" && !(pathLower.contains("/migrations/") || pathLower.hasPrefix("migrations/")) {
                rawSQLFileCount += 1
            }
        }

        let contentScanCandidates = localFiles.filter { shouldScanForDatabase(path: $0.path) }
        for file in contentScanCandidates {
            guard let content = try? workspace.readFile(project: project, path: file.path) else { continue }
            mergeDatabaseSignals(content: content.lowercased(), into: &engines)
        }

        var risks: [String] = []
        let sqlEngineCount = engines.intersection(sqlEngines).count
        if engines.isEmpty && (migrationCount > 0 || schemaCount > 0) {
            risks.append("Schema/migrations detected but DB engine is unclear.")
        }
        if !engines.isEmpty && migrationCount == 0 {
            risks.append("DB detected but no migrations folder was found.")
        }
        if sqlEngineCount > 1 {
            risks.append("Multiple SQL engines detected; verify this is intentional.")
        }
        if rawSQLFileCount >= 20 {
            risks.append("Many raw SQL files outside migrations (\(rawSQLFileCount)).")
        }

        return (
            engines: engines.sorted(),
            migrationCount: migrationCount,
            schemaCount: schemaCount,
            risks: risks
        )
    }

    private func shouldScanForDatabase(path: String) -> Bool {
        let pathLower = path.lowercased()
        let fileName = (pathLower as NSString).lastPathComponent
        let trackedNames: Set<String> = [
            "package.json", "requirements.txt", "pyproject.toml", "pipfile", "pipfile.lock",
            "poetry.lock", "docker-compose.yml", "docker-compose.yaml", ".env", ".env.example",
            ".env.local", "schema.prisma", "alembic.ini"
        ]

        if trackedNames.contains(fileName) { return true }
        if pathLower.contains("database") && (fileName.hasSuffix(".yml") || fileName.hasSuffix(".yaml") || fileName.hasSuffix(".json")) { return true }
        if pathLower.contains("prisma") || pathLower.contains("alembic") || pathLower.contains("typeorm") || pathLower.contains("sequelize") || pathLower.contains("drizzle") {
            return true
        }
        return false
    }

    private func mergeDatabaseSignals(content: String, into engines: inout Set<String>) {
        let markers: [(String, [String])] = [
            ("PostgreSQL", ["postgres://", "postgresql://", "\"pg\"", "psycopg", "asyncpg"]),
            ("MySQL", ["mysql://", "\"mysql2\"", "pymysql", "mysqlclient", "aiomysql"]),
            ("SQLite", ["sqlite://", "sqlite3", "better-sqlite3"]),
            ("MongoDB", ["mongodb://", "mongodb+srv://", "mongoose", "pymongo", "motor"]),
            ("Redis", ["redis://", "ioredis", "\"redis\"", "redis-py"])
        ]

        for (engine, hints) in markers where hints.contains(where: { content.contains($0) }) {
            engines.insert(engine)
        }
    }
}
