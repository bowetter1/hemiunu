import SwiftUI

// MARK: - Code File Entry & Row

struct CodeFileEntry: Identifiable {
    let id: String
    let name: String
    let path: String
    let depth: Int
    let isDirectory: Bool

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}

struct CodeFileRow: View {
    let entry: CodeFileEntry
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: entry.isDirectory ? 11 : 10))
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(entry.name)
                    .font(.system(size: entry.isDirectory ? 12 : 11, weight: entry.isDirectory ? .medium : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, CGFloat(entry.depth * 16) + 10)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        if entry.isDirectory { return "folder.fill" }
        return FileTypeAppearance.icon(for: entry.fileExtension)
    }

    private var iconColor: Color {
        if entry.isDirectory { return .blue.opacity(0.7) }
        return FileTypeAppearance.color(for: entry.fileExtension)
    }
}
