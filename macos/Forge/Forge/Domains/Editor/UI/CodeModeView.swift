import Foundation
import SwiftUI

/// Code Mode command center with file tree, editor, insights, and context dock
struct CodeModeView: View {
    enum MainAreaTab: String, CaseIterable {
        case code = "Code"
        case dashboard = "Dashboard"
    }

    var appState: AppState
    @Binding var selectedPageId: String?
    @State var viewModel: CodeViewModel
    @State var commandQuery: String = ""
    @State private var mainAreaTab: MainAreaTab = .code
    @State private var gitBranch: String = "no-git"
    @State private var isGitDirty = false
    @AppStorage("codeMode.lastSelectedProjectId") private var lastSelectedProjectId: String = ""

    private let fileTreeWidth: CGFloat = 250

    init(appState: AppState, selectedPageId: Binding<String?>) {
        self.appState = appState
        _selectedPageId = selectedPageId
        _viewModel = State(wrappedValue: CodeViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()

            HSplitView {
                fileTreeSection
                    .frame(minWidth: 200, idealWidth: fileTreeWidth, maxWidth: 320)

                editorSection
                    .frame(minWidth: 420)

                insightsSection
                    .frame(minWidth: 290, idealWidth: 330, maxWidth: 420)
            }

            Divider()
            contextDock
                .frame(height: 96)
        }
        .onAppear {
            appState.refreshLocalProjects()
            let validProjectIds = Set(appState.localProjects.map { "local:\($0.name)" })
            let preferredProjectId: String? = {
                if let selected = appState.selectedProjectId, validProjectIds.contains(selected) {
                    return selected
                }
                if !lastSelectedProjectId.isEmpty, validProjectIds.contains(lastSelectedProjectId) {
                    return lastSelectedProjectId
                }
                return appState.localProjects.first.map { "local:\($0.name)" }
            }()

            if let preferredProjectId {
                lastSelectedProjectId = preferredProjectId
                if appState.selectedProjectId != preferredProjectId {
                    appState.setSelectedProjectId(preferredProjectId)
                    Task {
                        await appState.loadProject(id: preferredProjectId)
                        viewModel.loadFiles()
                        await refreshGitSummary()
                    }
                } else {
                    viewModel.loadFiles()
                    Task { await refreshGitSummary() }
                }
            } else {
                viewModel.loadFiles()
                Task { await refreshGitSummary() }
            }
        }
        .onChange(of: appState.currentProject?.id) { _, _ in
            if let selected = appState.selectedProjectId, !selected.isEmpty {
                lastSelectedProjectId = selected
            }
            viewModel.loadFiles()
            Task { await refreshGitSummary() }
        }
    }

    // MARK: - Command Bar

    private var commandBar: some View {
        HStack(spacing: 10) {
            Text("CODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            projectPicker
            gitStatusPill

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search symbol/file...", text: $commandQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))

            commandButton(title: "Explain", icon: "text.bubble", action: runExplain)
            commandButton(title: "Refactor", icon: "wand.and.stars", action: runRefactor)
            commandButton(title: "Domain Scan", icon: "brain.head.profile", action: runDeepScan)
            commandButton(title: "Run Tests", icon: "checkmark.circle", action: runTests)
            commandButton(title: "Commit", icon: "arrow.triangle.branch", action: commitChanges)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - File Tree Section

    private var fileTreeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(viewModel.files.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: viewModel.loadFiles) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingFiles)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if viewModel.isLoadingFiles {
                VStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
            } else {
                FileTreeView(
                    files: viewModel.files,
                    selectedPath: $viewModel.selectedFilePath,
                    onFileSelect: viewModel.loadFileContent
                )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(spacing: 0) {
            mainAreaHeader
            Divider()

            if mainAreaTab == .dashboard {
                dashboardMainArea
            } else {
                if let path = viewModel.selectedFilePath {
                    CodeEditorView(
                        content: $viewModel.currentFileContent,
                        fileName: (path as NSString).lastPathComponent,
                        language: detectLanguage(path),
                        isLoading: viewModel.isLoadingContent,
                        onSave: viewModel.saveCurrentFile
                    )
                } else {
                    emptyEditorState
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var mainAreaHeader: some View {
        HStack {
            Picker("", selection: $mainAreaTab) {
                ForEach(MainAreaTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyEditorState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Select a file to edit")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Helpers

    private var projectPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if projectPickerItems.isEmpty {
                Text("No Project")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Picker("Project", selection: selectedProjectBinding) {
                    ForEach(projectPickerItems, id: \.id) { item in
                        Text(item.label).tag(item.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 260)
            }
        }
    }

    private var projectPickerItems: [(id: String, label: String)] {
        appState.localProjects.map { project in
            ("local:\(project.name)", projectLabel(for: project))
        }
    }

    private var selectedProjectBinding: Binding<String> {
        Binding(
            get: {
                appState.selectedProjectId
                    ?? projectPickerItems.first?.id
                    ?? ""
            },
            set: { newValue in
                selectProject(id: newValue)
            }
        )
    }

    private func selectProject(id: String) {
        guard !id.isEmpty, id != appState.selectedProjectId else { return }
        viewModel.selectedFilePath = nil
        viewModel.currentFileContent = ""
        lastSelectedProjectId = id
        appState.setSelectedProjectId(id)
        Task {
            await appState.loadProject(id: id)
            viewModel.loadFiles()
            await refreshGitSummary()
        }
    }

    private func projectLabel(for project: LocalProject) -> String {
        let parts = project.name.components(separatedBy: "/")
        let versionSuffix = parts.count == 2 ? " (\(parts[1]))" : ""
        if let title = project.briefTitle, !title.isEmpty {
            return title + versionSuffix
        }
        if let agent = project.agentName, !agent.isEmpty, parts.count == 2 {
            return "\(parts[0])\(versionSuffix) • \(agent)"
        }
        return project.name
    }

    private var gitStatusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(gitBranch)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Circle()
                .fill(isGitDirty ? .orange : .green)
                .frame(width: 6, height: 6)

            Text(isGitDirty ? "dirty" : "clean")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: .capsule)
        .frame(maxWidth: 220, alignment: .leading)
    }

    private var activeLocalProjectName: String? {
        if let selectedId = appState.selectedProjectId,
           let localName = appState.localProjectName(from: selectedId) {
            return localName
        }
        if let currentId = appState.currentProject?.id,
           let localName = appState.localProjectName(from: currentId) {
            return localName
        }
        return nil
    }

    private func refreshGitSummary() async {
        guard let projectName = activeLocalProjectName else {
            gitBranch = "no-project"
            isGitDirty = false
            return
        }
        let branch = (try? await appState.workspace.gitCurrentBranch(project: projectName)) ?? "no-git"
        let dirty = (try? await appState.workspace.gitIsDirty(project: projectName)) ?? false
        gitBranch = branch
        isGitDirty = dirty
    }

    private func commandButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func detectLanguage(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "python"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "jsx": return "javascriptreact"
        case "tsx": return "typescriptreact"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "md": return "markdown"
        case "swift": return "swift"
        default: return "text"
        }
    }
}
