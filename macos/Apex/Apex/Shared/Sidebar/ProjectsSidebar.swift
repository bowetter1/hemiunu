import SwiftUI

struct ProjectsSidebar: View {
    @ObservedObject var client: APIClient
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Projects")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onNewProject) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Project")
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Project list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.projects) { project in
                        ProjectRowExpandable(
                            project: project,
                            pages: client.pages,
                            isSelected: selectedProjectId == project.id,
                            selectedPageId: $selectedPageId,
                            onSelectProject: {
                                selectedProjectId = project.id
                                selectedPageId = nil
                            },
                            onSelectPage: { pageId in
                                selectedProjectId = project.id
                                selectedPageId = pageId
                            },
                            onDelete: {
                                Task {
                                    try? await client.deleteProject(projectId: project.id)
                                    if selectedProjectId == project.id {
                                        selectedProjectId = nil
                                        selectedPageId = nil
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()

            // New project button at bottom
            Button(action: onNewProject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("New Project")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.1))
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProjectRowExpandable: View {
    let project: Project
    let pages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectProject: () -> Void
    let onSelectPage: (String) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    // Get layout pages for this project (only when selected)
    var layoutPages: [Page] {
        guard isSelected else { return [] }
        return pages.filter { $0.layoutVariant != nil }
            .sorted { ($0.layoutVariant ?? 0) < ($1.layoutVariant ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Project row
            Button(action: onSelectProject) {
                HStack(spacing: 10) {
                    // Expand indicator
                    Image(systemName: isSelected && !layoutPages.isEmpty ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(formattedDate)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text(statusText)
                                .font(.system(size: 10))
                                .foregroundColor(statusColor)
                        }
                    }

                    Spacer()

                    // Three-dot menu
                    if isHovering || isSelected {
                        Menu {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected && selectedPageId == nil ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            // Page list (expanded when selected)
            if isSelected && !layoutPages.isEmpty {
                VStack(spacing: 2) {
                    ForEach(layoutPages) { page in
                        PageRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { onSelectPage(page.id) }
                        )
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
    }

    var projectTitle: String {
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: project.createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return ""
    }

    var statusColor: Color {
        switch project.status {
        case .brief, .clarification, .moodboard, .layouts:
            return .orange
        case .editing, .done:
            return .green
        case .failed:
            return .red
        }
    }

    var statusText: String {
        switch project.status {
        case .brief: return "Starting"
        case .clarification: return "Need info"
        case .moodboard: return "Moodboard"
        case .layouts: return "Layouts"
        case .editing: return "Editing"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }
}

struct PageRow: View {
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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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

#Preview {
    ProjectsSidebar(
        client: APIClient(),
        selectedProjectId: .constant(nil),
        selectedPageId: .constant(nil),
        onNewProject: {}
    )
    .frame(height: 400)
}
