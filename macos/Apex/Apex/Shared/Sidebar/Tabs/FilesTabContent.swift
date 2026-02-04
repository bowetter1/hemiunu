import SwiftUI

// MARK: - Files Tab Content

struct FilesTabContent: View {
    @ObservedObject var appState: AppState
    private var client: APIClient { appState.client }
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentProject != nil {
                if appState.isLocalProject {
                    // Local projects: always keep project list for layout switching
                    projectsList
                } else if currentMode == .code {
                    filesList
                } else {
                    variantsList
                }

                // Research data link
                if appState.currentProject?.moodboard != nil {
                    researchDataRow
                }
            } else {
                projectsList
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Project Dropdown

    private var projectDropdown: some View {
        Menu {
            // Local projects (grouped by session)
            if !appState.localProjects.isEmpty {
                ForEach(groupedLocalProjects) { group in
                    if group.projects.count == 1 {
                        Button(action: { selectedProjectId = "local:\(group.projects[0].name)" }) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(group.displayName)
                                if selectedProjectId == "local:\(group.projects[0].name)" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } else {
                        Menu {
                            ForEach(Array(group.projects.enumerated()), id: \.element.id) { index, project in
                                Button(action: { selectedProjectId = "local:\(project.name)" }) {
                                    HStack {
                                        Text("Layout \(index + 1)")
                                        if selectedProjectId == "local:\(project.name)" {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.stack")
                                Text(group.displayName)
                            }
                        }
                    }
                }
            }

            // Server projects
            if !appState.projects.isEmpty {
                if !appState.localProjects.isEmpty { Divider() }
                ForEach(appState.projects) { project in
                    Button(action: { selectedProjectId = project.id }) {
                        HStack {
                            Circle()
                                .fill(statusColor(for: project))
                                .frame(width: 8, height: 8)
                            Text(projectTitle(project))
                            if project.id == appState.currentProject?.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if appState.currentProject != nil {
                Divider()
                Button(action: onNewProject) {
                    Label("Back to Projects", systemImage: "arrow.left")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let project = appState.currentProject {
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
        ProjectFormatters.projectTitle(project)
    }

    private func statusColor(for project: Project) -> Color {
        ProjectFormatters.statusColor(for: project)
    }

    // MARK: - Research Data Row

    private var researchDataRow: some View {
        Button(action: {
            selectedPageId = nil
            showResearchJSON = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(showResearchJSON ? .blue : .secondary)
                    .frame(width: 16)

                Text("Research Data")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text("JSON")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(showResearchJSON ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.top, 4)
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
        PageFilters.rootPages(from: appState.pages)
    }

    /// Child pages for a given parent page
    private func childPages(for parentId: String) -> [Page] {
        PageFilters.childPages(for: parentId, from: appState.pages)
    }

    // MARK: - Code Files List (local workspace)

    /// Paths and directories to hide from the code file listing
    private static let hiddenDirs: Set<String> = [".git", "skills", "node_modules", "__pycache__", ".next"]
    private static let hiddenFileNames: Set<String> = [".env", ".mcp.json", "mcp_tools.py", ".gitignore"]
    private static let hiddenExtensions: Set<String> = ["md"]

    private static func shouldShowFile(_ file: LocalFileInfo) -> Bool {
        let name = (file.path as NSString).lastPathComponent
        if name.hasPrefix(".") { return false }
        if hiddenFileNames.contains(name) { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        if hiddenExtensions.contains(ext) { return false }
        let components = file.path.components(separatedBy: "/")
        for component in components {
            if hiddenDirs.contains(component) || component.hasPrefix(".") { return false }
        }
        return true
    }

    /// Build a flat list of file entries with depth info for rendering
    private var codeFileEntries: [CodeFileEntry] {
        let files = appState.localFiles.filter { Self.shouldShowFile($0) }
        var entries: [CodeFileEntry] = []
        var seenDirs: Set<String> = []

        let sorted = files.sorted { $0.path < $1.path }

        for file in sorted {
            let components = file.path.components(separatedBy: "/")

            // Add parent directories that haven't been added yet
            for i in 0..<(components.count - 1) {
                let dirPath = components[0...i].joined(separator: "/")
                if !seenDirs.contains(dirPath) {
                    seenDirs.insert(dirPath)
                    entries.append(CodeFileEntry(
                        id: "dir-\(dirPath)",
                        name: components[i],
                        path: dirPath,
                        depth: i,
                        isDirectory: true
                    ))
                }
            }

            // Add file (skip directory entries — we build them from paths above)
            if !file.isDirectory {
                entries.append(CodeFileEntry(
                    id: file.path,
                    name: (file.path as NSString).lastPathComponent,
                    path: file.path,
                    depth: components.count - 1,
                    isDirectory: false
                ))
            }
        }

        return entries
    }

    private var codeFilesList: some View {
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
                LazyVStack(spacing: 1) {
                    ForEach(codeFileEntries) { entry in
                        CodeFileRow(
                            entry: entry,
                            isSelected: isCodeFileSelected(entry),
                            onSelect: { selectCodeFile(entry) }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    private func isCodeFileSelected(_ entry: CodeFileEntry) -> Bool {
        guard let pageId = selectedPageId else { return false }
        return pageId.hasSuffix("/\(entry.path)")
    }

    private func selectCodeFile(_ entry: CodeFileEntry) {
        guard !entry.isDirectory else { return }
        if entry.path.hasSuffix(".html") {
            if let page = appState.pages.first(where: { $0.id.hasSuffix("/\(entry.path)") }) {
                selectedPageId = page.id
                showResearchJSON = false
            }
        }
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
                    if !appState.variants.isEmpty {
                        // Show variants with their pages
                        ForEach(appState.variants) { variant in
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
        PageFilters.pagesForVariant(variantId, from: appState.pages)
    }

    private var pagesWithoutVariant: [Page] {
        PageFilters.pagesWithoutVariant(from: appState.pages)
    }

    /// Root layout pages (pages without a parent - these are layout/hero pages)
    private var rootLayoutPages: [Page] {
        PageFilters.pagesWithoutVariant(from: appState.pages).filter { $0.parentPageId == nil }
    }

    /// Child pages for a given parent layout page
    private func childPagesFor(_ parentId: String) -> [Page] {
        PageFilters.childPages(for: parentId, from: appState.pages)
    }

    // MARK: - Projects List

    private var hasAnyProjects: Bool {
        !appState.projects.isEmpty || !appState.localProjects.isEmpty
    }

    private var groupedLocalProjects: [LocalProjectGroup] {
        LocalProjectGroup.group(appState.localProjects)
    }

    private func deleteLocalGroup(_ group: LocalProjectGroup) {
        let fm = FileManager.default
        for project in group.projects {
            try? fm.removeItem(at: project.path)
        }
        // Also remove the session directory if empty (works for both single and multi-project groups)
        if let first = group.projects.first {
            let sessionDir = first.path.deletingLastPathComponent()
            let remaining = (try? fm.contentsOfDirectory(atPath: sessionDir.path))?.filter { $0 != ".DS_Store" && $0 != "project-name.txt" } ?? []
            if remaining.isEmpty {
                try? fm.removeItem(at: sessionDir)
            }
        }
        // Clear selection if deleted project was selected
        if let sel = selectedProjectId, sel.hasPrefix("local:") {
            let selName = String(sel.dropFirst(6))
            if group.projects.contains(where: { $0.name == selName }) {
                appState.clearCurrentProject()
            }
        }
        appState.refreshLocalProjects()
    }

    private var projectsList: some View {
        VStack(spacing: 0) {
            if hasAnyProjects {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Local projects (grouped by session)
                        if !appState.localProjects.isEmpty {
                            sectionHeader("Local")
                            ForEach(groupedLocalProjects) { group in
                                SidebarSessionRow(
                                    group: group,
                                    selectedProjectId: selectedProjectId,
                                    onSelect: { name in selectedProjectId = "local:\(name)" },
                                    onDelete: { deleteLocalGroup(group) },
                                    pages: appState.pages,
                                    selectedPageId: selectedPageId,
                                    onSelectPage: { pageId in
                                        selectedPageId = pageId
                                        showResearchJSON = false
                                    }
                                )
                            }
                        }

                        // Server projects
                        if !appState.projects.isEmpty {
                            if !appState.localProjects.isEmpty {
                                Divider().padding(.vertical, 6)
                            }
                            sectionHeader("Cloud")
                            ForEach(appState.projects) { project in
                                SidebarProjectRow(
                                    project: project,
                                    isSelected: selectedProjectId == project.id,
                                    onSelect: { selectedProjectId = project.id },
                                    onDelete: {
                                        Task {
                                            try? await client.projectService.delete(projectId: project.id)
                                            appState.projects.removeAll { $0.id == project.id }
                                            if selectedProjectId == project.id {
                                                selectedProjectId = nil
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(8)
                }
                .onAppear { appState.refreshLocalProjects() }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No projects yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Create a project from the\ntools panel on the right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
        switch entry.fileExtension {
        case "html": return "doc.text.fill"
        case "css": return "paintbrush.fill"
        case "js", "ts": return "curlybraces"
        case "json": return "doc.badge.gearshape"
        case "jpg", "jpeg", "png", "gif", "svg", "webp": return "photo"
        case "py": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        if entry.isDirectory { return .blue.opacity(0.7) }
        switch entry.fileExtension {
        case "html": return .orange
        case "css": return .blue
        case "js", "ts": return .yellow
        case "json": return .purple
        case "jpg", "jpeg", "png", "gif", "svg", "webp": return .green
        case "py": return .cyan
        default: return .secondary
        }
    }
}
