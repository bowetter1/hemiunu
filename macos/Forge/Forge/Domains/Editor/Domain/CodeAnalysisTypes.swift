import Foundation

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
