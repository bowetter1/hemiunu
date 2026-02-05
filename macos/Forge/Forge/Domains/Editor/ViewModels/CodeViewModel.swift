import SwiftUI
import Combine

/// CodeViewModel — owns file tree state and code editing logic
@MainActor
class CodeViewModel: ObservableObject {
    @Published var files: [FileTreeNode] = []
    @Published var selectedFilePath: String?
    @Published var currentFileContent: String = ""
    @Published var isLoadingFiles = false
    @Published var isLoadingContent = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let appState: AppState
    private var workspace: LocalWorkspaceService { appState.workspace }

    init(appState: AppState) {
        self.appState = appState
    }

    var currentProjectId: String? {
        appState.currentProject?.id
    }

    /// Extract local project name from "local:name" ID
    private var localProjectName: String? {
        guard let id = currentProjectId else { return nil }
        return appState.localProjectName(from: id)
    }

    // MARK: - File Operations

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

    // MARK: - Local File Tree Builder

    /// Build a hierarchical FileTreeNode array from flat LocalFileInfo list
    private func buildFileTree(from localFiles: [LocalFileInfo]) -> [FileTreeNode] {
        var root: [String: FileTreeNode] = [:]
        var dirNodes: [String: FileTreeNode] = [:]

        let sorted = localFiles.sorted { $0.path < $1.path }

        for file in sorted where !file.isDirectory {
            let components = file.path.components(separatedBy: "/")

            // Ensure parent directories exist
            for i in 0..<(components.count - 1) {
                let dirPath = components[0...i].joined(separator: "/")
                if dirNodes[dirPath] == nil {
                    dirNodes[dirPath] = FileTreeNode(
                        id: dirPath,
                        name: components[i],
                        path: dirPath,
                        isDirectory: true,
                        size: 0,
                        fileType: nil,
                        children: []
                    )
                }
            }

            // Create file node
            let node = FileTreeNode(
                id: file.path,
                name: file.name,
                path: file.path,
                isDirectory: false,
                size: file.size,
                fileType: (file.name as NSString).pathExtension,
                children: []
            )

            if components.count > 1 {
                let parentPath = components[0..<(components.count - 1)].joined(separator: "/")
                dirNodes[parentPath]?.children.append(node)
            } else {
                root[file.path] = node
            }
        }

        // Build directory hierarchy
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
