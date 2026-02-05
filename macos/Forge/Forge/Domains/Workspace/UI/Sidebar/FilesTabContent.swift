import SwiftUI

// MARK: - Files Tab Content

struct FilesTabContent: View {
    @ObservedObject var appState: AppState
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
            } else {
                projectsList
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
        !appState.localProjects.isEmpty
    }

    private var groupedLocalProjects: [LocalProjectGroup] {
        LocalProjectGroup.group(appState.localProjects)
    }

    private func deleteLocalGroup(_ group: LocalProjectGroup) {
        let fm = FileManager.default
        for project in group.projects {
            try? fm.removeItem(at: project.path)
        }
        // Also remove the session directory if empty
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
