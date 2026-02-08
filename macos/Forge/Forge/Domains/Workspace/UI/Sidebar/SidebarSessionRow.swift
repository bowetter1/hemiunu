import SwiftUI

// MARK: - Session Group Row

struct SidebarSessionRow: View {
    let group: LocalProjectGroup
    let selectedProjectId: String?
    let onSelect: (String) -> Void
    var onDelete: (() -> Void)? = nil
    var pages: [Page] = []
    var selectedPageId: String? = nil
    var onSelectPage: ((String) -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        multiProjectGroup
            .onAppear {
                if group.projects.count == 1 {
                    isExpanded = true
                }
            }
    }

    // MARK: - Project Group

    private var multiProjectGroup: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 8) {
                    Text(group.displayName)
                        .font(.system(size: 12, weight: isSelected(group) ? .medium : .regular))
                        .foregroundStyle(isSelected(group) ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected(group) ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: { onDelete?() }) {
                    Label("Delete", systemImage: "trash")
                }
            }

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(Array(group.projects.enumerated()), id: \.element.id) { index, project in
                        VStack(spacing: 0) {
                            Button(action: { onSelect(project.name) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isSelected(project) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 7, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 8)

                                    Text(project.agentName ?? "Layout \(index + 1)")
                                        .font(.system(size: 11, weight: isSelected(project) ? .medium : .regular))
                                        .foregroundStyle(isSelected(project) ? .primary : .tertiary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.leading, 26)
                                .padding(.trailing, 10)
                                .padding(.vertical, 4)
                                .background(isSelected(project) ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if isSelected(project), !pages.isEmpty {
                                pageRows
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Page Rows

    private var pageRows: some View {
        VStack(spacing: 1) {
            ForEach(pages) { page in
                Button(action: { onSelectPage?(page.id) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        Text(pageDisplayName(page.name))
                            .font(.system(size: 10))
                            .foregroundStyle(selectedPageId == page.id ? .primary : .tertiary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(selectedPageId == page.id ? Color.blue.opacity(0.08) : Color.clear)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 44)
        .padding(.top, 2)
    }

    private func pageDisplayName(_ name: String) -> String {
        let base = name.replacingOccurrences(of: ".html", with: "")
        return base.replacingOccurrences(of: "-", with: " ").capitalized
    }

    // MARK: - Helpers

    private func isSelected(_ group: LocalProjectGroup) -> Bool {
        group.projects.contains { isSelected($0) }
    }

    private func isSelected(_ project: LocalProject) -> Bool {
        selectedProjectId == "local:\(project.name)"
    }
}
