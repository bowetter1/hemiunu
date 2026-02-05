import Foundation

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
