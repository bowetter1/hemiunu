import SwiftUI

// MARK: - Files Tab Content

struct FilesTabContent: View {
    var appState: AppState
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentProject != nil {
                if currentMode == .code {
                    codeFilesList
                } else {
                    projectsList
                }
            } else {
                projectsList
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Code Files List (local workspace)

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

    private var codeFileEntries: [CodeFileEntry] {
        let files = appState.localFiles.filter { Self.shouldShowFile($0) }
        var entries: [CodeFileEntry] = []
        var seenDirs: Set<String> = []
        let sorted = files.sorted { $0.path < $1.path }

        for file in sorted {
            let components = file.path.components(separatedBy: "/")
            for i in 0..<(components.count - 1) {
                let dirPath = components[0...i].joined(separator: "/")
                if !seenDirs.contains(dirPath) {
                    seenDirs.insert(dirPath)
                    entries.append(CodeFileEntry(
                        id: "dir-\(dirPath)", name: components[i],
                        path: dirPath, depth: i, isDirectory: true
                    ))
                }
            }
            if !file.isDirectory {
                entries.append(CodeFileEntry(
                    id: file.path, name: (file.path as NSString).lastPathComponent,
                    path: file.path, depth: components.count - 1, isDirectory: false
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
                    .foregroundStyle(.secondary)
                Text("Files")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
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
            }
        }
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
        if let first = group.projects.first {
            let sessionDir = first.path.deletingLastPathComponent()
            let remaining = (try? fm.contentsOfDirectory(atPath: sessionDir.path))?.filter { $0 != ".DS_Store" && $0 != "project-name.txt" } ?? []
            if remaining.isEmpty {
                try? fm.removeItem(at: sessionDir)
            }
        }
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
                                }
                            )
                        }
                    }
                    .padding(8)
                }
                .onAppear { appState.refreshLocalProjects() }
            } else {
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("No projects yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Create a project from the\ntools panel on the right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
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
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}
