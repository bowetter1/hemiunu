import Foundation
import SwiftUI

private struct DomainMoveCandidate: Identifiable {
    let raw: String
    let filePath: String?
    let line: Int?

    var id: String { raw }
}

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
                    dashboardSection
                    codexDomainReportSection

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

                    architectureMapSection
                    flowMapSection

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

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightSectionHeader("Dashboard")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8, alignment: .top),
                GridItem(.flexible(), spacing: 8, alignment: .top)
            ], spacing: 8) {
                dashboardCard(title: "Snapshot", icon: "chart.xyaxis.line") {
                    dashboardMetric(label: "Files", value: "\(viewModel.totalFileCount)")
                    dashboardMetric(label: "Folders", value: "\(viewModel.totalDirectoryCount)")
                    dashboardMetric(label: "LOC", value: "\(viewModel.totalSourceLines)")
                    dashboardMetric(
                        label: "Largest",
                        value: viewModel.largestFile.map { "\($0.lines)l" } ?? "n/a"
                    )
                }

                dashboardCard(title: "File Types", icon: "doc.on.doc") {
                    if viewModel.fileTypeMetrics.isEmpty {
                        dashboardInfo("No files scanned yet.")
                    } else {
                        ForEach(viewModel.fileTypeMetrics.prefix(4)) { metric in
                            HStack(spacing: 6) {
                                Text(metric.displayName)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(metric.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                dashboardCard(title: "Database", icon: "cylinder.split.1x2") {
                    dashboardMetric(
                        label: "Detected",
                        value: viewModel.detectedDatabases.isEmpty
                            ? "none"
                            : viewModel.detectedDatabases.joined(separator: ", ")
                    )
                    dashboardMetric(label: "Migrations", value: "\(viewModel.dbMigrationCount)")
                    dashboardMetric(label: "Schema files", value: "\(viewModel.dbSchemaCount)")
                    dashboardMetric(label: "Risks", value: "\(viewModel.dbRiskFlags.count)")
                }

                dashboardCard(title: "Maintenance", icon: "wrench.and.screwdriver") {
                    dashboardMetric(label: "Changed", value: "\(viewModel.changedFiles.count)")
                    dashboardMetric(label: "Hotspots", value: "\(viewModel.largeFiles.count)")
                    dashboardMetric(label: "Rule issues", value: "\(viewModel.architectureViolations.count)")
                    dashboardMetric(label: "TODO/FIXME", value: "\(viewModel.todoCount)")
                }
            }

            if let firstRisk = viewModel.dbRiskFlags.first {
                insightInfo("DB risk: \(firstRisk)")
            }
        }
    }

    private var architectureMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightSectionHeader("Architecture Map")

            if filteredArchitectureModules.isEmpty {
                insightInfo("No module map available yet.")
            } else {
                ForEach(filteredArchitectureModules.prefix(5)) { module in
                    HStack(spacing: 6) {
                        Text(module.module)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(module.fileCount)f")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(module.lines)l")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                }
            }

            if filteredArchitectureLinks.isEmpty {
                insightInfo("No internal module links found.")
            } else {
                ForEach(filteredArchitectureLinks.prefix(6)) { link in
                    HStack(spacing: 6) {
                        Text("\(link.fromModule) -> \(link.toModule)")
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Text("\(link.count)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                }
            }
        }
    }

    private var flowMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightSectionHeader("Flow Map")

            if filteredFlowMapEntries.isEmpty {
                insightInfo("No endpoint flow entries detected.")
            } else {
                ForEach(filteredFlowMapEntries.prefix(6)) { entry in
                    insightRow(
                        title: "\(entry.method) \(entry.endpoint)",
                        subtitle: "\(entry.chain) • \(entry.filePath)",
                        badge: "FLOW",
                        badgeColor: .blue,
                        onTap: { openFile(entry.filePath) }
                    )
                }
            }
        }
    }

    private func dashboardCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
    }

    private func dashboardMetric(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func dashboardInfo(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var codexDomainReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightSectionHeader("Domain Architecture (Codex)")

            if let report = latestDomainReport {
                let domains = domainReportLines(section: "DETECTED_DOMAINS", from: report)
                let moves = parseDomainMoveCandidates(from: report)
                let boundaryIssues = domainReportLines(section: "BOUNDARY_ISSUES", from: report)

                if domains.isEmpty {
                    insightInfo("No detected domains parsed from latest report.")
                } else {
                    ForEach(Array(domains.prefix(6).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                    }
                }

                if moves.isEmpty {
                    insightInfo("No move candidates parsed yet.")
                } else {
                    ForEach(moves.prefix(6)) { candidate in
                        if let path = candidate.filePath {
                            let lineSuffix = candidate.line.map { ":\($0)" } ?? ""
                            insightRow(
                                title: "Move candidate: \(path)\(lineSuffix)",
                                subtitle: candidate.raw,
                                badge: "MOVE",
                                badgeColor: .blue,
                                onTap: { openFile(path) }
                            )
                        } else {
                            Text(candidate.raw)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                        }
                    }
                }

                if let firstIssue = boundaryIssues.first {
                    insightInfo("Boundary issue: \(firstIssue)")
                }
            } else {
                insightInfo("No domain report yet. Run Domain Scan to let Codex map domains and move candidates.")
                Button(action: runDeepScan) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                        Text("Run Domain Scan")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
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
                dockChip(title: "DB risks", value: "\(viewModel.dbRiskFlags.count)")
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

    private var filteredArchitectureModules: [ArchitectureModuleMetric] {
        if normalizedQuery.isEmpty { return viewModel.architectureModules }
        return viewModel.architectureModules.filter { module in
            module.module.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredArchitectureLinks: [ArchitectureLinkMetric] {
        if normalizedQuery.isEmpty { return viewModel.architectureLinks }
        return viewModel.architectureLinks.filter { link in
            link.fromModule.localizedCaseInsensitiveContains(normalizedQuery)
                || link.toModule.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredFlowMapEntries: [FlowMapEntry] {
        if normalizedQuery.isEmpty { return viewModel.flowMapEntries }
        return viewModel.flowMapEntries.filter { entry in
            entry.method.localizedCaseInsensitiveContains(normalizedQuery)
                || entry.endpoint.localizedCaseInsensitiveContains(normalizedQuery)
                || entry.chain.localizedCaseInsensitiveContains(normalizedQuery)
                || entry.filePath.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var latestDomainReport: String? {
        appState.chatViewModel.messages.reversed().first { message in
            guard message.role == .assistant else { return false }
            return message.content.contains("DETECTED_DOMAINS")
                || message.content.contains("MOVE_CANDIDATES")
        }?.content
    }

    private func domainReportLines(section: String, from report: String) -> [String] {
        let lines = report.components(separatedBy: .newlines)
        var inSection = false
        var results: [String] = []

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "```" { continue }

            if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") {
                let heading = trimmed
                    .replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                if heading == section {
                    inSection = true
                    continue
                }
                if inSection {
                    break
                }
                continue
            }

            guard inSection else { continue }
            if trimmed.hasPrefix("- ") {
                results.append(String(trimmed.dropFirst(2)))
            } else if let dotIndex = trimmed.firstIndex(of: "."), trimmed[..<dotIndex].allSatisfy({ $0.isNumber }) {
                let nextIndex = trimmed.index(after: dotIndex)
                results.append(String(trimmed[nextIndex...]).trimmingCharacters(in: .whitespaces))
            }
        }

        return results
    }

    private func parseDomainMoveCandidates(from report: String) -> [DomainMoveCandidate] {
        domainReportLines(section: "MOVE_CANDIDATES", from: report).map { line in
            let extracted = extractFilePathAndLine(from: line)
            return DomainMoveCandidate(
                raw: line,
                filePath: extracted?.path,
                line: extracted?.line
            )
        }
    }

    private func extractFilePathAndLine(from line: String) -> (path: String, line: Int?)? {
        let pattern = #"([A-Za-z0-9_./\-]+\.[A-Za-z0-9]+)(?::([0-9]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }

        let pathRange = match.range(at: 1)
        guard pathRange.location != NSNotFound else { return nil }
        let rawPath = nsLine.substring(with: pathRange)
        let normalizedPath = rawPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "./", with: "")

        var extractedLine: Int?
        if match.numberOfRanges > 2 {
            let lineRange = match.range(at: 2)
            if lineRange.location != NSNotFound {
                extractedLine = Int(nsLine.substring(with: lineRange))
            }
        }

        return normalizedPath.isEmpty ? nil : (path: normalizedPath, line: extractedLine)
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

    private func runDeepScan() {
        let moduleSample = viewModel.architectureModules.prefix(8).map {
            "\($0.module) (\($0.fileCount) files, \($0.lines) LOC)"
        }.joined(separator: "\n")
        let linkSample = viewModel.architectureLinks.prefix(10).map {
            "\($0.fromModule) -> \($0.toModule) (\($0.count))"
        }.joined(separator: "\n")
        let flowSample = viewModel.flowMapEntries.prefix(10).map {
            "\($0.method) \($0.endpoint) => \($0.chain) [\($0.filePath)]"
        }.joined(separator: "\n")
        let largeFilesSample = viewModel.largeFiles.prefix(10).map {
            "\($0.path) (\($0.lines) lines)"
        }.joined(separator: "\n")
        let dbEngines = viewModel.detectedDatabases.isEmpty
            ? "none"
            : viewModel.detectedDatabases.joined(separator: ", ")
        let dbRisks = viewModel.dbRiskFlags.isEmpty
            ? "none"
            : viewModel.dbRiskFlags.joined(separator: " | ")

        let prompt = """
        Do a deep domain-architecture scan of this project.
        Focus on domain boundaries and what should be moved to improve AI-readiness.
        Use tools to inspect files directly and validate findings.

        Project snapshot:
        - Health score: \(viewModel.healthScore)/100
        - Files: \(viewModel.totalFileCount)
        - LOC (tracked source): \(viewModel.totalSourceLines)
        - Large files: \(viewModel.largeFiles.count)
        - Rule issues: \(viewModel.architectureViolations.count)
        - DB engines: \(dbEngines)
        - DB risks: \(dbRisks)

        Current architecture modules:
        \(moduleSample.isEmpty ? "n/a" : moduleSample)

        Current architecture links:
        \(linkSample.isEmpty ? "n/a" : linkSample)

        Current endpoint flows:
        \(flowSample.isEmpty ? "n/a" : flowSample)

        Largest files:
        \(largeFilesSample.isEmpty ? "n/a" : largeFilesSample)

        Return plain markdown with these exact headings (no JSON, no code block):
        ### DETECTED_DOMAINS
        - domain name | why | key files/functions
        ### MOVE_CANDIDATES
        - file_path:line | function/symbol | current domain | target domain | reason
        ### BOUNDARY_ISSUES
        - issue | affected files
        ### ACTION_ORDER
        - priority item with impact/effort
        """

        appState.chatViewModel.sendMessage(prompt)
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
