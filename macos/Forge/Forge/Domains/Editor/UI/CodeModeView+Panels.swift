import Foundation
import SwiftUI

extension CodeModeView {
    // MARK: - Insights

    var insightsSection: some View {
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

    var contextDock: some View {
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

    private var filteredLargeFiles: [CodeFileMetric] {
        if normalizedQuery.isEmpty { return viewModel.largeFiles }
        return viewModel.largeFiles.filter { $0.path.localizedCaseInsensitiveContains(normalizedQuery) || $0.layer.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private var filteredViolations: [ArchitectureViolation] {
        if normalizedQuery.isEmpty { return viewModel.architectureViolations }
        return viewModel.architectureViolations.filter {
            $0.filePath.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.importedModule.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.rule.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredDependencies: [LayerDependency] {
        if normalizedQuery.isEmpty { return viewModel.layerDependencies }
        return viewModel.layerDependencies.filter {
            $0.fromLayer.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.toLayer.localizedCaseInsensitiveContains(normalizedQuery)
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

    private func openFile(_ path: String) {
        viewModel.selectedFilePath = path
        viewModel.loadFileContent(path)
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 55 { return .orange }
        return .red
    }
}
