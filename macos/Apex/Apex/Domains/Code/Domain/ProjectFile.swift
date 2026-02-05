import Foundation

/// Represents a file in the project (from MongoDB)
struct ProjectFile: Codable, Identifiable, Equatable {
    let path: String
    var content: String?
    let fileType: String?
    let size: Int

    var id: String { path }

    var name: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        (path as NSString).deletingLastPathComponent
    }

    var fileExtension: String {
        (path as NSString).pathExtension.lowercased()
    }

    var icon: String {
        switch fileExtension {
        case "py": return "text.badge.star"
        case "js", "jsx": return "j.square"
        case "ts", "tsx": return "t.square"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        case "yaml", "yml": return "list.bullet.rectangle"
        case "sh": return "terminal"
        case "sql": return "cylinder"
        case "swift": return "swift"
        case "rs": return "gearshape.2"
        case "go": return "g.square"
        default: return "doc"
        }
    }

    var iconColor: String {
        switch fileExtension {
        case "py": return "python"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "html": return "html"
        case "css", "scss": return "css"
        case "json": return "json"
        case "md": return "markdown"
        case "swift": return "swift"
        default: return "default"
        }
    }

    enum CodingKeys: String, CodingKey {
        case path
        case content
        case fileType = "file_type"
        case size
    }
}

/// File tree node for hierarchical display
struct FileTreeNode: Identifiable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int
    let fileType: String?
    var children: [FileTreeNode]
    var isExpanded: Bool = true

    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "text.badge.star"
        case "js", "jsx": return "j.square"
        case "ts", "tsx": return "t.square"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        default: return "doc"
        }
    }
}

/// Response from list files endpoint
struct FileListResponse: Codable {
    let files: [FileInfo]
    let tree: [FileTreeItem]
    let total: Int
}

struct FileInfo: Codable {
    let path: String
    let fileType: String?
    let size: Int

    enum CodingKeys: String, CodingKey {
        case path
        case fileType = "file_type"
        case size
    }
}

struct FileTreeItem: Codable {
    let name: String
    let path: String
    let isDir: Bool
    let size: Int
    let fileType: String?
    let children: [FileTreeItem]

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case isDir = "is_dir"
        case size
        case fileType = "file_type"
        case children
    }

    func toNode() -> FileTreeNode {
        FileTreeNode(
            id: path,
            name: name,
            path: path,
            isDirectory: isDir,
            size: size,
            fileType: fileType,
            children: children.map { $0.toNode() }
        )
    }
}

