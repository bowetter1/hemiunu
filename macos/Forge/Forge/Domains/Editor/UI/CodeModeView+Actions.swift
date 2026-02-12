import Foundation

extension CodeModeView {
    func runExplain() {
        guard let file = viewModel.selectedFilePath else { return }
        appState.chatViewModel.sendMessage("Explain architecture, responsibilities, and risks in `\(file)`.")
    }

    func runRefactor() {
        guard let file = viewModel.selectedFilePath else { return }
        appState.chatViewModel.sendMessage("Propose a safe refactor plan for `\(file)` with minimal behavior change.")
    }

    func runDeepScan() {
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

    func runTests() {
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

    func commitChanges() {
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
}
