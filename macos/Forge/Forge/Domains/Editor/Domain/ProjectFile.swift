import Foundation

/// Represents a file in the project
struct ProjectFile: Identifiable, Equatable {
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
        case "swift": return "swift"
        default: return "doc"
        }
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
