import SwiftUI

/// Code Mode command center with file tree, editor, insights, and context dock
struct CodeModeView: View {
    var appState: AppState
    @Binding var selectedPageId: String?
    @State private var viewModel: CodeViewModel
    @State private var commandQuery: String = ""

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
            viewModel.loadFiles()
        }
        .onChange(of: appState.currentProject?.id) { _, _ in
            viewModel.loadFiles()
        }
    }

    // MARK: - Command Bar

    private var commandBar: some View {
        HStack(spacing: 10) {
            Text("CODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            Text(projectDisplayName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search symbol/file…", text: $commandQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))

            commandButton(title: "Explain", icon: "text.bubble", action: runExplain)
            commandButton(title: "Refactor", icon: "wand.and.stars", action: runRefactor)
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
        .background(Color(nsColor: .textBackgroundColor))
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

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Insights")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    healthCard

                    insightSectionHeader("Large Files")
                    ForEach(filteredLargeFiles.prefix(5)) { metric in
                        insightRow(
                            title: metric.path,
                            subtitle: "\(metric.lines) lines • \(metric.layer)",
                            badge: metric.lines >= viewModel.largeFileLineThreshold ? "LARGE" : nil,
                            badgeColor: .red,
                            onTap: { openFile(metric.path) }
                        )
                    }

                    insightSectionHeader("Architecture")
                    if filteredViolations.isEmpty {
                        insightInfo("No domain rule violations.")
                    } else {
                        ForEach(filteredViolations.prefix(5)) { violation in
                            insightRow(
                                title: violation.filePath,
                                subtitle: "\(violation.rule) • \(violation.importedModule)",
                                badge: "RULE",
                                badgeColor: .orange,
                                onTap: { openFile(violation.filePath) }
                            )
                        }
                    }

                    insightSectionHeader("Layer Dependencies")
                    if filteredDependencies.isEmpty {
                        insightInfo("No cross-layer dependencies found.")
                    } else {
                        ForEach(filteredDependencies.prefix(6)) { dep in
                            HStack {
                                Text("\(dep.fromLayer) -> \(dep.toLayer)")
                                    .font(.system(size: 10, design: .monospaced))
                                Spacer()
                                Text("\(dep.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                        }
                    }

                    insightSectionHeader("Flow Highlights")
                    if filteredFlows.isEmpty {
                        insightInfo("No API flow highlights.")
                    } else {
                        ForEach(Array(filteredFlows.prefix(4).enumerated()), id: \.offset) { _, flow in
                            Text(flow)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                        }
                    }
                }
                .padding(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Project Health")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(viewModel.healthScore)/100")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(healthColor(viewModel.healthScore))
            }

            ProgressView(value: Double(viewModel.healthScore), total: 100)
                .tint(healthColor(viewModel.healthScore))

            Text("\(viewModel.largeFiles.count) large files • \(viewModel.architectureViolations.count) rule issues • \(viewModel.todoCount) TODO/FIXME")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
    }

    private func insightSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func insightInfo(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
    }

    private func insightRow(
        title: String,
        subtitle: String,
        badge: String?,
        badgeColor: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.1), in: .rect(cornerRadius: 4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Context Dock

    private var contextDock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dockChip(title: "Changed files", value: "\(viewModel.changedFiles.count)")
                dockChip(title: "Hotspots", value: "\(viewModel.largeFiles.count)")
                dockChip(title: "Recent AI", value: "\(recentAIActionCount)")
                dockChip(title: "Open TODOs", value: "\(viewModel.todoCount)")
                dockChip(title: "Snapshots", value: "\(appState.pageVersions.count)")
                if let selected = viewModel.selectedFilePath {
                    dockChip(title: "Current", value: selected)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(dockPaths.prefix(10), id: \.self) { path in
                        Button(action: { openFile(path) }) {
                            Text(path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func dockChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: .capsule)
    }

    // MARK: - Helpers

    private var projectDisplayName: String {
        appState.currentProject?.brief ?? "No Project"
    }

    private func openFile(_ path: String) {
        viewModel.selectedFilePath = path
        viewModel.loadFileContent(path)
    }

    private var filteredLargeFiles: [CodeFileMetric] {
        if normalizedQuery.isEmpty { return viewModel.largeFiles }
        return viewModel.largeFiles.filter { $0.path.localizedCaseInsensitiveContains(normalizedQuery) || $0.layer.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private var filteredViolations: [ArchitectureViolation] {
        if normalizedQuery.isEmpty { return viewModel.architectureViolations }
        return viewModel.architectureViolations.filter {
            $0.filePath.localizedCaseInsensitiveContains(normalizedQuery) ||
            $0.importedModule.localizedCaseInsensitiveContains(normalizedQuery) ||
            $0.rule.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredDependencies: [LayerDependency] {
        if normalizedQuery.isEmpty { return viewModel.layerDependencies }
        return viewModel.layerDependencies.filter {
            $0.fromLayer.localizedCaseInsensitiveContains(normalizedQuery) ||
            $0.toLayer.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredFlows: [String] {
        if normalizedQuery.isEmpty { return viewModel.flowHighlights }
        return viewModel.flowHighlights.filter { $0.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private var normalizedQuery: String {
        commandQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentAIActionCount: Int {
        appState.chatViewModel.messages.suffix(20).count
    }

    private var dockPaths: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for path in viewModel.changedFiles + viewModel.largeFiles.map(\.path) {
            if seen.contains(path) { continue }
            seen.insert(path)
            ordered.append(path)
        }
        return ordered
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 55 { return .orange }
        return .red
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

    private func runExplain() {
        guard let file = viewModel.selectedFilePath else { return }
        appState.chatViewModel.sendMessage("Explain architecture, responsibilities, and risks in `\(file)`.")
    }

    private func runRefactor() {
        guard let file = viewModel.selectedFilePath else { return }
        appState.chatViewModel.sendMessage("Propose a safe refactor plan for `\(file)` with minimal behavior change.")
    }

    private func runTests() {
        guard let project = localProjectName else { return }
        Task {
            let projectURL = appState.workspace.projectPath(project)
            let command = testCommand(for: project)
            do {
                let result = try await appState.workspace.exec(command, cwd: projectURL, timeout: 60)
                appState.errorMessage = result.succeeded
                    ? "Tests finished successfully."
                    : "Tests failed (exit \(result.exitCode))."
            } catch {
                appState.errorMessage = "Failed to run tests: \(error.localizedDescription)"
            }
        }
    }

    private func commitChanges() {
        guard let project = localProjectName else { return }
        Task {
            do {
                let result = try await appState.workspace.gitCommit(project: project, message: "Code view snapshot")
                appState.errorMessage = result.succeeded
                    ? "Committed changes."
                    : "Commit failed (exit \(result.exitCode))."
                viewModel.loadFiles()
            } catch {
                appState.errorMessage = "Commit failed: \(error.localizedDescription)"
            }
        }
    }

    private var localProjectName: String? {
        guard let id = appState.currentProject?.id else { return nil }
        return appState.localProjectName(from: id)
    }

    private func testCommand(for projectName: String) -> String {
        let files = appState.workspace.listFiles(project: projectName)
        if files.contains(where: { $0.path == "requirements.txt" || $0.path.hasSuffix(".py") }) {
            return "pytest -q"
        }
        if files.contains(where: { $0.path == "package.json" }) {
            return "npm test -- --watch=false"
        }
        return "echo 'No supported test runner found.'"
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
