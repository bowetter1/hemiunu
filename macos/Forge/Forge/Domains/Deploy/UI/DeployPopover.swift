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
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?

    private var hasKey: Bool { DaytonaService.hasAPIKey }

    private var helper: ProjectVersionHelper {
        ProjectVersionHelper(appState: appState, selectedVersion: selectedVersion)
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
            selectedVersion = helper.currentVersion
            loadSandboxInfo()
        }
        .onChange(of: selectedVersion) { _, _ in
            loadSandboxInfo()
        }
        .onDisappear {
            pollingTask?.cancel()
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
                if let builder = helper.selectedBuilderName {
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
            if helper.versions.count > 1 {
                Picker("", selection: $selectedVersion) {
                    ForEach(helper.versions, id: \.self) { v in
                        Text(helper.builderName(for: v) ?? v).tag(v)
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
                    Text(isDeploying ? "Deploying..." : "Deploy to Daytona")
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

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
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
        let projectName = helper.selectedProjectName
        guard !projectName.isEmpty else { return }

        isDeploying = true
        errorMessage = nil
        let deployStartedAt = Date()
        let baseline = readSandboxInfo(projectName: projectName)
        chatViewModel.sendMessage("Deploy version \(selectedVersion) to Daytona sandbox")

        // Poll sandbox.json for an updated deployment result.
        pollingTask = Task {
            let url = await waitForDeploymentURL(projectName: projectName, baseline: baseline, startedAt: deployStartedAt)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if url == nil {
                    errorMessage = "Deploy timed out — check activity log for details"
                }
                deployURL = url
                isDeploying = false
                loadSandboxInfo()
            }
        }
    }

    private func restartSandbox(_ sandbox: SandboxInfo) {
        isRestarting = true
        errorMessage = nil
        Task {
            do {
                try await DaytonaService.startSandbox(id: sandbox.sandboxId)
                await MainActor.run {
                    sandboxState = "started"
                    isRestarting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRestarting = false
                }
            }
        }
    }

    private func loadSandboxInfo() {
        let projectName = helper.selectedProjectName
        guard !projectName.isEmpty else {
            savedSandbox = nil
            sandboxState = nil
            return
        }
        guard let sandbox = readSandboxInfo(projectName: projectName) else {
            savedSandbox = nil
            sandboxState = nil
            return
        }

        savedSandbox = sandbox

        // Fetch live state
        Task {
            let state = await DaytonaService.sandboxState(id: sandbox.sandboxId)
            await MainActor.run { sandboxState = state }
        }
    }

    private func readSandboxInfo(projectName: String) -> SandboxInfo? {
        let file = appState.workspace.projectPath(projectName).appendingPathComponent("sandbox.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sandboxId = json["sandbox_id"] as? String else {
            return nil
        }

        let previewURL = json["preview_url"] as? String
        var createdAt: Date?
        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr)
        }

        return SandboxInfo(sandboxId: sandboxId, previewURL: previewURL, createdAt: createdAt)
    }

    private func waitForDeploymentURL(projectName: String, baseline: SandboxInfo?, startedAt: Date) async -> String? {
        for _ in 0..<180 {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return nil }
            guard let latest = readSandboxInfo(projectName: projectName) else { continue }
            guard isNewDeployment(latest, baseline: baseline, startedAt: startedAt) else { continue }
            if let url = latest.previewURL, !url.isEmpty {
                return url
            }
        }
        return nil
    }

    private func isNewDeployment(_ latest: SandboxInfo, baseline: SandboxInfo?, startedAt: Date) -> Bool {
        guard let baseline else {
            // No prior sandbox info: any written deployment artifact is new.
            return true
        }

        if latest.sandboxId != baseline.sandboxId {
            return true
        }

        if latest.previewURL != baseline.previewURL, latest.previewURL != nil {
            return true
        }

        if let latestCreatedAt = latest.createdAt {
            return latestCreatedAt >= startedAt
        }

        return latest.createdAt != baseline.createdAt
    }
}

// MARK: - Sandbox Info

private struct SandboxInfo {
    let sandboxId: String
    let previewURL: String?
    let createdAt: Date?
}
