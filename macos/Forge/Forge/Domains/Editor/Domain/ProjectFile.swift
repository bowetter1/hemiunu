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
        return FileTypeAppearance.icon(forPath: path)
    }
}
