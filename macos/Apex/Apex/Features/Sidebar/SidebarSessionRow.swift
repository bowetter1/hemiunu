import SwiftUI

// MARK: - Session Group Row

struct SidebarSessionRow: View {
    let group: LocalProjectGroup
    let selectedProjectId: String?
    let onSelect: (String) -> Void
    var onDelete: (() -> Void)? = nil
    /// Pages for the currently selected project (shown as children under the active layout)
    var pages: [Page] = []
    var selectedPageId: String? = nil
    var onSelectPage: ((String) -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        if group.projects.count == 1 {
            singleProjectRow
        } else {
            multiProjectGroup
        }
    }

    // MARK: - Single Project

    @ViewBuilder
    private var singleProjectRow: some View {
        if let project = group.projects.first {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Button(action: { onSelect(project.name) }) {
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text(relativeDate(project.modifiedAt))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(role: .destructive, action: { onDelete?() }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected(project) ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)

                // Pages under this project
                if isSelected(project), pages.count > 1 {
                    pageRows
                }
            }
        }
    }

    // MARK: - Multi-Project Group

    private var multiProjectGroup: some View {
        VStack(spacing: 0) {
            // Session header — expand/collapse only
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if group.hasBriefTitle {
                            Text(group.dateLabel)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button(role: .destructive, action: { onDelete?() }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Layout rows
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(Array(group.projects.enumerated()), id: \.element.id) { index, project in
                        VStack(spacing: 0) {
                            Button(action: { onSelect(project.name) }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(isSelected(project) ? Color.blue : Color.secondary.opacity(0.3))
                                        .frame(width: 6, height: 6)

                                    Text(project.agentName ?? "Layout \(index + 1)")
                                        .font(.system(size: 11, weight: isSelected(project) ? .medium : .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected(project) ? Color.blue.opacity(0.15) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // Pages under selected layout
                            if isSelected(project), pages.count > 1 {
                                pageRows
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    // MARK: - Page Rows

    private var pageRows: some View {
        VStack(spacing: 1) {
            ForEach(pages) { page in
                Button(action: { onSelectPage?(page.id) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 9))
                            .foregroundColor(selectedPageId == page.id ? .blue : .secondary.opacity(0.6))
                            .frame(width: 12)

                        Text(pageDisplayName(page.name))
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(selectedPageId == page.id ? Color.blue.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.top, 2)
    }

    /// Strip .html and capitalize for display
    private func pageDisplayName(_ name: String) -> String {
        let base = name.replacingOccurrences(of: ".html", with: "")
        return base.replacingOccurrences(of: "-", with: " ").capitalized
    }

    // MARK: - Helpers

    private func isSelected(_ project: LocalProject) -> Bool {
        selectedProjectId == "local:\(project.name)"
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
