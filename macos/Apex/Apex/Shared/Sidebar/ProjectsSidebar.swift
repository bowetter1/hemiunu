import SwiftUI

struct ProjectsSidebar: View {
    @ObservedObject var client: APIClient
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Project dropdown at top
            projectDropdown
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            if client.currentProject != nil {
                if currentMode == .code {
                    // Code mode: show files
                    filesSidebar
                } else {
                    // Design mode: show variants and pages
                    variantsSidebar
                }
            } else {
                // Show project list when no project is selected
                projectsSidebar
            }
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Files Sidebar (Code mode)

    private var filesSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Files")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Files list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.pages) { page in
                        FileRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { selectedPageId = page.id }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    // MARK: - Project Dropdown

    private var projectDropdown: some View {
        Menu {
            ForEach(client.projects) { project in
                Button(action: { selectedProjectId = project.id }) {
                    HStack {
                        Circle()
                            .fill(statusColor(for: project))
                            .frame(width: 8, height: 8)
                        Text(projectTitle(project))
                        if project.id == client.currentProject?.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if client.currentProject != nil {
                Divider()
                Button(action: onNewProject) {
                    Label("Back to Projects", systemImage: "arrow.left")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let project = client.currentProject {
                    Circle()
                        .fill(statusColor(for: project))
                        .frame(width: 8, height: 8)
                    Text(projectTitle(project))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text("Select Project")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func projectTitle(_ project: Project) -> String {
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    private func statusColor(for project: Project) -> Color {
        switch project.status {
        case .brief, .clarification, .moodboard, .layouts:
            return .orange
        case .editing, .done:
            return .green
        case .failed:
            return .red
        }
    }

    // MARK: - Variants Sidebar (when project is selected)

    private var variantsSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Variants")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { /* TODO: Add variant */ }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Variant")
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Variants list
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Show variants if they exist
                    if !client.variants.isEmpty {
                        ForEach(client.variants) { variant in
                            VariantRowExpandable(
                                variant: variant,
                                pages: pagesForVariant(variant.id),
                                isSelected: selectedVariantId == variant.id,
                                selectedPageId: $selectedPageId,
                                onSelectVariant: {
                                    selectedVariantId = variant.id
                                    // Select first page in variant
                                    if let firstPage = pagesForVariant(variant.id).first {
                                        selectedPageId = firstPage.id
                                    }
                                },
                                onSelectPage: { pageId in
                                    selectedVariantId = variant.id
                                    selectedPageId = pageId
                                },
                                onAddPage: {
                                    // TODO: Add page to variant
                                }
                            )
                        }
                    } else {
                        // Legacy: show pages without variants (layout_variant based)
                        ForEach(legacyLayoutPages) { page in
                            LegacyPageRow(
                                page: page,
                                isSelected: selectedPageId == page.id,
                                onSelect: { selectedPageId = page.id }
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()

            // New variant button
            if !client.variants.isEmpty {
                Button(action: { /* TODO: Add variant */ }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("New Variant")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color.blue.opacity(0.1))
            }
        }
    }

    private func pagesForVariant(_ variantId: String) -> [Page] {
        client.pages.filter { $0.variantId == variantId }
    }

    private var legacyLayoutPages: [Page] {
        client.pages.filter { $0.layoutVariant != nil }
            .sorted { ($0.layoutVariant ?? 0) < ($1.layoutVariant ?? 0) }
    }

    // MARK: - Projects Sidebar (when no project is selected)

    private var projectsSidebar: some View {
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
                        ProjectRow(
                            project: project,
                            isSelected: selectedProjectId == project.id,
                            onSelect: { selectedProjectId = project.id },
                            onDelete: {
                                Task {
                                    try? await client.deleteProject(projectId: project.id)
                                    if selectedProjectId == project.id {
                                        selectedProjectId = nil
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()

            // New project button
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
    }
}

// MARK: - Variant Row

struct VariantRowExpandable: View {
    let variant: Variant
    let pages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectVariant: () -> Void
    let onSelectPage: (String) -> Void
    let onAddPage: () -> Void

    @State private var isExpanded = true
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Variant row
            Button(action: {
                onSelectVariant()
                isExpanded = true
            }) {
                HStack(spacing: 10) {
                    // Expand indicator
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)

                    // Variant icon
                    Image(systemName: "paintpalette")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .blue : .secondary)

                    Text(variant.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Page count badge
                    Text("\(pages.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
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

            // Pages list (expanded)
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(pages) { page in
                        PageRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { onSelectPage(page.id) }
                        )
                    }

                    // Add page button
                    Button(action: onAddPage) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)

                            Text("Add Page")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Page Row

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

                Text(page.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Version indicator
                if page.currentVersion > 1 {
                    Text("v\(page.currentVersion)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Page Row (for layout_variant based pages)

struct LegacyPageRow: View {
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

// MARK: - Project Row (for project list)

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

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

                // Delete button on hover
                if isHovering {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
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
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
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
}

// MARK: - File Row (Code mode)

struct FileRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: fileIcon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)

                Text(fileName)
                    .font(.system(size: 12))
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

    private var fileName: String {
        let name = page.name.lowercased().replacingOccurrences(of: " ", with: "-")
        return "\(name).html"
    }

    private var fileIcon: String {
        "doc.text.fill"
    }

    private var iconColor: Color {
        .orange
    }
}

#Preview {
    ProjectsSidebar(
        client: APIClient(),
        currentMode: .design,
        selectedProjectId: .constant(nil),
        selectedVariantId: .constant(nil),
        selectedPageId: .constant(nil),
        onNewProject: {}
    )
    .frame(height: 400)
}
