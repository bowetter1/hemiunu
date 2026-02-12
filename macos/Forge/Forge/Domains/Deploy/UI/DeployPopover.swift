import SwiftUI

/// Deploy popover — API key setup or one-click deploy
struct DeployPopover: View {
    let appState: AppState
    let chatViewModel: ChatViewModel

    @State private var apiKey = ""
    @State private var selectedVersion = "v1"
    @State private var isDeploying = false
    @State private var isRestarting = false
    @State private var deployURL: String?
    @State private var savedSandbox: SandboxInfo?
    @State private var sandboxState: String?

    private var hasKey: Bool { DaytonaService.hasAPIKey }

    /// Available version directories for current project
    private var versions: [String] {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return ["v1"] }
        let projectName = String(selectedId.dropFirst(6))
        let parts = projectName.components(separatedBy: "/")
        if parts.count == 2 {
            // Already a version project — find siblings
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

    /// Builder name for the currently viewed version
    private var currentBuilderName: String? {
        builderName(for: currentVersion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !hasKey {
                apiKeySetup
            } else if let url = deployURL {
                deployedState(url: url)
            } else {
                deployReady
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            selectedVersion = currentVersion
            loadSandboxInfo()
        }
    }

    // MARK: - API Key Setup

    private var apiKeySetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daytona API Key")
                .font(.system(size: 12, weight: .semibold))

            Text("Get your key from app.daytona.io")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Button("Save") {
                guard !apiKey.isEmpty else { return }
                KeychainHelper.save(key: DaytonaService.keychainKey, value: apiKey)
                apiKey = ""
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(apiKey.isEmpty)
        }
    }

    // MARK: - Deploy Ready

    private var deployReady: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with current builder
            HStack(spacing: 6) {
                Text("Daytona Sandbox")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let builder = currentBuilderName {
                    Text(builder)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Previous sandbox info
            if let sandbox = savedSandbox {
                previousSandbox(sandbox)
            }

            Divider().opacity(savedSandbox != nil ? 0.5 : 0)

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
                deploy()
            } label: {
                HStack(spacing: 6) {
                    if isDeploying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isDeploying ? "Deploying..." : "Deploy")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isDeploying)

            if isDeploying {
                Text("Check activity log for progress")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Previous Sandbox

    private func previousSandbox(_ sandbox: SandboxInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(sandboxState ?? "unknown")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let created = sandbox.createdAt {
                    Text(created, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if let url = sandbox.previewURL {
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
            }

            // Restart button for stopped sandboxes
            if sandboxState == "stopped" || sandboxState == "archived" {
                Button {
                    restartSandbox(sandbox)
                } label: {
                    HStack(spacing: 6) {
                        if isRestarting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isRestarting ? "Starting..." : "Restart Sandbox")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRestarting)
            }
        }
    }

    private var stateColor: Color {
        switch sandboxState {
        case "started", "running": return .green
        case "stopped": return .orange
        case "archived": return .secondary
        default: return .secondary
        }
    }

    // MARK: - Deployed State

    private func deployedState(url: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Deployed!")
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

            Button("Deploy Again") {
                deployURL = nil
                isDeploying = false
                loadSandboxInfo()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Actions

    private func deploy() {
        isDeploying = true
        chatViewModel.sendMessage("Deploy version \(selectedVersion) to Daytona sandbox")

        // Poll chat messages for deploy URL
        Task {
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let url = findDeployURL() {
                    await MainActor.run {
                        deployURL = url
                        isDeploying = false
                    }
                    return
                }
            }
            await MainActor.run {
                isDeploying = false
            }
        }
    }

    private func restartSandbox(_ sandbox: SandboxInfo) {
        isRestarting = true
        Task {
            do {
                try await DaytonaService.startSandbox(id: sandbox.sandboxId)
                await MainActor.run {
                    sandboxState = "started"
                    isRestarting = false
                }
            } catch {
                await MainActor.run {
                    isRestarting = false
                }
            }
        }
    }

    private func loadSandboxInfo() {
        let projectName = currentProjectName
        guard !projectName.isEmpty else { return }
        let file = appState.workspace.projectPath(projectName).appendingPathComponent("sandbox.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sandboxId = json["sandbox_id"] as? String else { return }

        let previewURL = json["preview_url"] as? String
        var createdAt: Date?
        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr)
        }

        savedSandbox = SandboxInfo(sandboxId: sandboxId, previewURL: previewURL, createdAt: createdAt)

        // Fetch live state
        Task {
            let state = await DaytonaService.sandboxState(id: sandboxId)
            await MainActor.run { sandboxState = state }
        }
    }

    private func findDeployURL() -> String? {
        for message in chatViewModel.messages.reversed() {
            if let range = message.content.range(of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+"#, options: .regularExpression) {
                return String(message.content[range])
            }
        }
        return nil
    }
}

// MARK: - Sandbox Info

private struct SandboxInfo {
    let sandboxId: String
    let previewURL: String?
    let createdAt: Date?
}
