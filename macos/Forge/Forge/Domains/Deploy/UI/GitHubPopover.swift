import SwiftUI

/// GitHub popover — push project to a GitHub repo via `gh` CLI
struct GitHubPopover: View {
    let appState: AppState
    let chatViewModel: ChatViewModel

    @State private var repoName = ""
    @State private var isPrivate = false
    @State private var isPushing = false
    @State private var pushedURL: String?
    @State private var selectedVersion = "v1"
    @State private var savedGitHub: GitHubInfo?
    @State private var isAuthenticated = false
    @State private var checkingAuth = true
    @State private var errorMessage: String?

    private var ghAvailable: Bool { GitHubService.isAvailable }

    /// Available version directories for current project
    private var versions: [String] {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return ["v1"] }
        let projectName = String(selectedId.dropFirst(6))
        let parts = projectName.components(separatedBy: "/")
        if parts.count == 2 {
            let parent = parts[0]
            return appState.localProjects
                .filter { $0.name.hasPrefix("\(parent)/v") }
                .map { $0.name.components(separatedBy: "/").last ?? $0.name }
                .sorted()
        }
        return ["v1"]
    }

    /// Current project's version label
    private var currentVersion: String {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return "v1" }
        let name = String(selectedId.dropFirst(6))
        let parts = name.components(separatedBy: "/")
        return parts.count == 2 ? parts[1] : "v1"
    }

    /// Resolve project name for current selection
    private var currentProjectName: String {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return "" }
        return String(selectedId.dropFirst(6))
    }

    /// Parent project name (e.g. "coffee-shop" from "coffee-shop/v1")
    private var parentProjectName: String {
        let name = currentProjectName
        return name.components(separatedBy: "/").first ?? name
    }

    /// Read agent-name.txt for a version to get the builder name
    private func builderName(for version: String) -> String? {
        let project = "\(parentProjectName)/\(version)"
        return try? appState.workspace.readFile(project: project, path: "agent-name.txt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builder name for the selected version
    private var selectedBuilderName: String? {
        builderName(for: selectedVersion)
    }

    /// Project name for selected target (e.g. "coffee-shop/v2")
    private var selectedProjectName: String {
        guard !parentProjectName.isEmpty else { return "" }
        return "\(parentProjectName)/\(selectedVersion)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !ghAvailable {
                installView
            } else if checkingAuth {
                checkingAuthView
            } else if !isAuthenticated {
                authView
            } else if let url = pushedURL {
                pushedState(url: url)
            } else {
                pushReady
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            selectedVersion = currentVersion
            repoName = parentProjectName
            loadGitHubInfo()
            checkAuth()
        }
        .onChange(of: selectedVersion) { _, _ in
            loadGitHubInfo()
        }
    }

    // MARK: - Install View

    private var installView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GitHub CLI Required")
                .font(.system(size: 12, weight: .semibold))

            Text("Install the GitHub CLI to push projects.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Run in Terminal:")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("brew install gh\ngh auth login")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
            }
        }
    }

    // MARK: - Checking Auth

    private var checkingAuthView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Checking GitHub auth...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Auth View

    private var authView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GitHub Login Required")
                .font(.system(size: 12, weight: .semibold))

            Text("Authenticate with the GitHub CLI first.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Run in Terminal:")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("gh auth login")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
            }

            Button("Check Again") {
                checkAuth()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Push Ready

    private var pushReady: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with current builder
            HStack(spacing: 6) {
                Text("Push to GitHub")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let builder = selectedBuilderName {
                    Text(builder)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Previous push info
            if let github = savedGitHub {
                previousPush(github)
                Divider().opacity(0.5)
            }

            // Repo name (only for first push)
            if savedGitHub == nil {
                TextField("Repository name", text: $repoName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Picker("", selection: $isPrivate) {
                    Text("Public").tag(false)
                    Text("Private").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            // Version picker with builder names
            if versions.count > 1 {
                Picker("", selection: $selectedVersion) {
                    ForEach(versions, id: \.self) { v in
                        Text(builderName(for: v) ?? v).tag(v)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            Button {
                pushToGitHub()
            } label: {
                HStack(spacing: 6) {
                    if isPushing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isPushing ? "Pushing..." : (savedGitHub != nil ? "Push Again" : "Push to GitHub"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isPushing || repoName.isEmpty)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Previous Push

    private func previousPush(_ github: GitHubInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text(github.repo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let created = github.createdAt {
                    Text(created, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                if let nsURL = URL(string: github.url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                Text(github.url)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
    }

    // MARK: - Pushed State

    private func pushedState(url: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Pushed!")
                    .font(.system(size: 12, weight: .semibold))
            }

            Button {
                if let nsURL = URL(string: url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                Text(url)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Button("Push Again") {
                pushedURL = nil
                isPushing = false
                loadGitHubInfo()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Actions

    private func checkAuth() {
        checkingAuth = true
        Task {
            let authed = await GitHubService.isAuthenticated()
            await MainActor.run {
                isAuthenticated = authed
                checkingAuth = false
            }
        }
    }

    private func pushToGitHub() {
        let projectName = selectedProjectName
        guard !projectName.isEmpty, !repoName.isEmpty else { return }

        isPushing = true
        errorMessage = nil
        let cwd = appState.workspace.projectPath(projectName)

        Task {
            do {
                let url: String
                if savedGitHub != nil {
                    // Subsequent push — just git push
                    _ = try await GitHubService.push(cwd: cwd)
                    url = savedGitHub!.url
                } else {
                    // First push — create repo
                    url = try await GitHubService.createAndPush(name: repoName, isPrivate: isPrivate, cwd: cwd)
                }
                await MainActor.run {
                    pushedURL = url
                    isPushing = false
                    loadGitHubInfo()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPushing = false
                }
            }
        }
    }

    private func loadGitHubInfo() {
        let projectName = selectedProjectName
        guard !projectName.isEmpty else {
            savedGitHub = nil
            return
        }
        guard let info = readGitHubInfo(projectName: projectName) else {
            savedGitHub = nil
            return
        }
        savedGitHub = info
        repoName = info.repo
    }

    private func readGitHubInfo(projectName: String) -> GitHubInfo? {
        let file = appState.workspace.projectPath(projectName).appendingPathComponent("github.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let repo = json["repo"] as? String,
              let url = json["url"] as? String else {
            return nil
        }

        var createdAt: Date?
        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr)
        }

        return GitHubInfo(repo: repo, url: url, createdAt: createdAt)
    }
}

// MARK: - GitHub Info

private struct GitHubInfo {
    let repo: String
    let url: String
    let createdAt: Date?
}
