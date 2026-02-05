import SwiftUI

/// Centralized file type → icon and color mappings
enum FileTypeAppearance {
    /// SF Symbol icon for a file extension
    static func icon(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "py": return "text.badge.star"
        case "js", "jsx": return "j.square"
        case "ts", "tsx": return "t.square"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        case "swift": return "swift"
        case "jpg", "jpeg", "png", "gif", "svg", "webp": return "photo"
        default: return "doc"
        }
    }

    /// Color for a file extension
    static func color(for extension: String) -> Color {
        switch `extension`.lowercased() {
        case "py": return .yellow
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "html": return .orange
        case "css", "scss": return .purple
        case "json": return .green
        case "md": return .gray
        case "swift": return .orange
        case "jpg", "jpeg", "png", "gif", "svg", "webp": return .green
        default: return .secondary
        }
    }

    /// Icon for a file path (convenience)
    static func icon(forPath path: String) -> String {
        icon(for: (path as NSString).pathExtension)
    }

    /// Color for a file path (convenience)
    static func color(forPath path: String) -> Color {
        color(for: (path as NSString).pathExtension)
    }
}
