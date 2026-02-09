import SwiftUI

/// Displays project files in a tree structure
struct FileTreeView: View {
    let files: [FileTreeNode]
    @Binding var selectedPath: String?
    let onFileSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if files.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(files) { node in
                            FileTreeRow(
                                node: node,
                                selectedPath: $selectedPath,
                                depth: 0,
                                onSelect: onFileSelect
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No files yet")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Generate a project to get started")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct FileTreeRow: View {
    let node: FileTreeNode
    @Binding var selectedPath: String?
    let depth: Int
    let onSelect: (String) -> Void

    @State private var isExpanded: Bool = true
    @State private var isHovering = false

    private let indentWidth: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if depth > 0 {
                    Color.clear
                        .frame(width: CGFloat(depth) * indentWidth)
                }

                if node.isDirectory {
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 12)
                }

                Image(systemName: node.isDirectory ? (isExpanded ? "folder.fill" : "folder") : node.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if !node.isDirectory && node.size > 0 {
                    Text(formatSize(node.size))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    selectedPath = node.path
                    onSelect(node.path)
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }

            if node.isDirectory && isExpanded {
                ForEach(node.children) { child in
                    FileTreeRow(
                        node: child,
                        selectedPath: $selectedPath,
                        depth: depth + 1,
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    private var iconColor: Color {
        if node.isDirectory { return .blue }
        let ext = (node.path as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return .yellow
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "html": return .orange
        case "css", "scss": return .purple
        case "json": return .green
        case "md": return .gray
        case "swift": return .orange
        default: return .secondary
        }
    }

    private var backgroundColor: Color {
        if selectedPath == node.path { return Color.accentColor.opacity(0.2) }
        if isHovering { return Color.primary.opacity(0.05) }
        return Color.clear
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        else if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        else { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
    }
}
