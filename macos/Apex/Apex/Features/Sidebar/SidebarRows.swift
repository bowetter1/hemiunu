import SwiftUI

struct SidebarFileRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void
    var isRoot: Bool = true

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Tree connector for child pages
                if !isRoot {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 1)
                    }
                    .frame(width: 16, height: 20)
                }

                Text(fileName)
                    .font(.system(size: isRoot ? 12 : 11, weight: isRoot ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, isRoot ? 10 : 18)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var fileName: String {
        page.name.lowercased().replacingOccurrences(of: " ", with: "-") + ".html"
    }
}

struct SidebarVariantRow: View {
    let variant: Variant
    let pages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectVariant: () -> Void
    let onSelectPage: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                onSelectVariant()
                isExpanded = true
            }) {
                HStack(spacing: 8) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "paintpalette")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .blue : .secondary)

                    Text(variant.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(pages.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected && selectedPageId == nil ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(pages) { page in
                        SidebarPageRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { onSelectPage(page.id) }
                        )
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 4)
            }
        }
    }
}

struct SidebarPageRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(pageName)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if page.currentVersion > 1 {
                    Text("v\(page.currentVersion)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    var pageName: String {
        if let variant = page.layoutVariant {
            return "Layout \(variant)"
        }
        return page.name
    }
}

/// Layout page with expandable children (for Design mode)
struct SidebarLayoutPageRow: View {
    let page: Page
    let childPages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectPage: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Layout/Hero page row
            Button(action: { onSelectPage(page.id) }) {
                HStack(spacing: 8) {
                    // Expand/collapse button (only if has children)
                    if !childPages.isEmpty {
                        Button(action: { isExpanded.toggle() }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 10)
                    }

                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)

                    Text(pageName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if !childPages.isEmpty {
                        Text("\(childPages.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Child pages (indented)
            if isExpanded && !childPages.isEmpty {
                VStack(spacing: 1) {
                    ForEach(Array(childPages.enumerated()), id: \.element.id) { index, child in
                        Button(action: { onSelectPage(child.id) }) {
                            HStack(spacing: 6) {
                                // Tree connector line
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 1)

                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 1)
                                }
                                .frame(width: 16, height: 20)

                                Image(systemName: "doc.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue.opacity(0.7))

                                Text(child.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                            .background(selectedPageId == child.id ? Color.blue.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    var pageName: String {
        if let variant = page.layoutVariant {
            return "Layout \(variant)"
        }
        return page.name
    }
}

struct SidebarProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(formattedDate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Always visible 3-dot menu
            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }

    var projectTitle: String {
        ProjectFormatters.projectTitle(project)
    }

    var formattedDate: String {
        ProjectFormatters.formattedDate(project.createdAt)
    }

    var statusColor: Color {
        ProjectFormatters.statusColor(for: project)
    }
}
