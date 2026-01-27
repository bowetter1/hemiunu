import SwiftUI

// MARK: - Files Tab Content

struct FilesTabContent: View {
    @ObservedObject var client: APIClient
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Project dropdown for navigation
            projectDropdown
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if client.currentProject != nil {
                if currentMode == .code {
                    filesList
                } else {
                    variantsList
                }
            } else {
                projectsList
            }
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

    // MARK: - Files List (Code mode)

    private var filesList: some View {
        VStack(spacing: 0) {
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

            ScrollView {
                LazyVStack(spacing: 2) {
                    // Show root pages (no parent) with their children
                    ForEach(rootPages) { rootPage in
                        SidebarFileRow(
                            page: rootPage,
                            isSelected: selectedPageId == rootPage.id,
                            onSelect: { selectedPageId = rootPage.id; showResearchJSON = false },
                            isRoot: true
                        )

                        // Show child pages indented under this root
                        ForEach(childPages(for: rootPage.id)) { childPage in
                            SidebarFileRow(
                                page: childPage,
                                isSelected: selectedPageId == childPage.id,
                                onSelect: { selectedPageId = childPage.id; showResearchJSON = false },
                                isRoot: false
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    /// Root pages (pages without a parent - these are the layout/hero pages)
    private var rootPages: [Page] {
        client.pages.filter { $0.parentPageId == nil }
    }

    /// Child pages for a given parent page
    private func childPages(for parentId: String) -> [Page] {
        client.pages.filter { $0.parentPageId == parentId }
    }

    // MARK: - Variants List (Design mode)

    private var variantsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pages")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    if !client.variants.isEmpty {
                        // Show variants with their pages
                        ForEach(client.variants) { variant in
                            SidebarVariantRow(
                                variant: variant,
                                pages: pagesForVariant(variant.id),
                                isSelected: selectedVariantId == variant.id,
                                selectedPageId: $selectedPageId,
                                onSelectVariant: {
                                    selectedVariantId = variant.id
                                    showResearchJSON = false
                                    if let firstPage = pagesForVariant(variant.id).first {
                                        selectedPageId = firstPage.id
                                    }
                                },
                                onSelectPage: { pageId in
                                    selectedVariantId = variant.id
                                    selectedPageId = pageId
                                    showResearchJSON = false
                                }
                            )
                        }

                        // Show pages without variant (layout pages and their children)
                        if !pagesWithoutVariant.isEmpty {
                            Divider()
                                .padding(.vertical, 8)

                            // Group by parent: show root pages first, then children under them
                            ForEach(rootLayoutPages) { layoutPage in
                                SidebarLayoutPageRow(
                                    page: layoutPage,
                                    childPages: childPagesFor(layoutPage.id),
                                    isSelected: selectedPageId == layoutPage.id,
                                    selectedPageId: $selectedPageId,
                                    onSelectPage: { pageId in
                                        selectedPageId = pageId
                                        showResearchJSON = false
                                    }
                                )
                            }
                        }
                    } else {
                        // No variants - show pages grouped by parent
                        ForEach(rootLayoutPages) { layoutPage in
                            SidebarLayoutPageRow(
                                page: layoutPage,
                                childPages: childPagesFor(layoutPage.id),
                                isSelected: selectedPageId == layoutPage.id,
                                selectedPageId: $selectedPageId,
                                onSelectPage: { pageId in
                                    selectedPageId = pageId
                                    showResearchJSON = false
                                }
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    private func pagesForVariant(_ variantId: String) -> [Page] {
        client.pages.filter { $0.variantId == variantId }
    }

    private var pagesWithoutVariant: [Page] {
        client.pages.filter { $0.variantId == nil }
    }

    /// Root layout pages (pages without a parent - these are layout/hero pages)
    private var rootLayoutPages: [Page] {
        client.pages.filter { $0.variantId == nil && $0.parentPageId == nil }
    }

    /// Child pages for a given parent layout page
    private func childPagesFor(_ parentId: String) -> [Page] {
        client.pages.filter { $0.parentPageId == parentId }
    }

    // MARK: - Projects List

    private var projectsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.projects) { project in
                        SidebarProjectRow(
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
        }
    }
}


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

                Image(systemName: isRoot ? "rectangle.3.group" : "doc.fill")
                    .font(.system(size: isRoot ? 11 : 10))
                    .foregroundColor(isRoot ? .orange : .blue.opacity(0.7))

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
