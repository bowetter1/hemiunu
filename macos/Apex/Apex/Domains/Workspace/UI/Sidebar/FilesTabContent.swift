import SwiftUI

// MARK: - Files Tab Content

struct FilesTabContent: View {
    @ObservedObject var appState: AppState
    private var client: APIClient { appState.client }
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentProject != nil {
                if appState.isLocalProject {
                    projectsList
                } else if currentMode == .code {
                    filesList
                } else {
                    pagesList
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

    // MARK: - Pages List (Design mode)

    private var pagesList: some View {
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
                .padding(8)
            }

            Spacer()
        }
    }

    /// Root layout pages (pages without a parent)
    private var rootLayoutPages: [Page] {
        PageFilters.rootPages(from: appState.pages)
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
