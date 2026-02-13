import SwiftUI

/// Railway deploy popover — API key setup + one-click deploy
struct RailwayDeployPopover: View {
    let appState: AppState
    let chatViewModel: ChatViewModel

    @State private var apiKey = ""
    @State private var selectedVersion = "v1"
    @State private var isDeploying = false
    @State private var deployURL: String?
    @State private var savedRailway: RailwayInfo?
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?

    private var hasKey: Bool { RailwayAPIService.hasAPIKey }

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
            loadRailwayInfo()
        }
        .onChange(of: selectedVersion) { _, _ in
            loadRailwayInfo()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }

    // MARK: - API Key Setup

    private var apiKeySetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Railway API Key")
                .font(.system(size: 12, weight: .semibold))

            Text("Get your key from railway.com/account/tokens")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Button("Save") {
                guard !apiKey.isEmpty else { return }
                KeychainHelper.save(key: RailwayAPIService.keychainKey, value: apiKey)
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
                Text("Railway Deploy")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let builder = helper.selectedBuilderName {
                    Text(builder)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Previous deploy info
            if let railway = savedRailway {
                previousDeploy(railway)
                Divider().opacity(0.5)
            }

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
                    Text(isDeploying ? "Deploying..." : "Deploy to Railway")
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

    // MARK: - Previous Deploy

    private func previousDeploy(_ railway: RailwayInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text(railway.serviceName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let created = railway.createdAt {
                    Text(created, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                if let nsURL = URL(string: railway.url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                Text(railway.url)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
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
                loadRailwayInfo()
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
        let baseline = readRailwayInfo(projectName: projectName)
        chatViewModel.sendMessage("Deploy version \(selectedVersion) to Railway")

        // Poll railway.json for an updated deployment result.
        pollingTask = Task {
            let url = await waitForDeploymentURL(projectName: projectName, baseline: baseline, startedAt: deployStartedAt)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if url == nil {
                    errorMessage = "Deploy timed out — check activity log for details"
                }
                deployURL = url
                isDeploying = false
                loadRailwayInfo()
            }
        }
    }

    private func loadRailwayInfo() {
        let projectName = helper.selectedProjectName
        guard !projectName.isEmpty else {
            savedRailway = nil
            return
        }
        guard let info = readRailwayInfo(projectName: projectName) else {
            savedRailway = nil
            return
        }
        savedRailway = info
    }

    private func readRailwayInfo(projectName: String) -> RailwayInfo? {
        let file = appState.workspace.projectPath(projectName).appendingPathComponent("railway.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serviceName = json["service_name"] as? String,
              let url = json["url"] as? String else {
            return nil
        }

        var createdAt: Date?
        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr)
        }

        return RailwayInfo(serviceName: serviceName, url: url, createdAt: createdAt)
    }

    private func waitForDeploymentURL(projectName: String, baseline: RailwayInfo?, startedAt: Date) async -> String? {
        for _ in 0..<180 {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return nil }
            guard let latest = readRailwayInfo(projectName: projectName) else { continue }
            guard isNewDeployment(latest, baseline: baseline, startedAt: startedAt) else { continue }
            if !latest.url.isEmpty {
                return latest.url
            }
        }
        return nil
    }

    private func isNewDeployment(_ latest: RailwayInfo, baseline: RailwayInfo?, startedAt: Date) -> Bool {
        guard let baseline else {
            // No prior deploy info: any written deployment artifact is new.
            return true
        }

        if latest.serviceName != baseline.serviceName {
            return true
        }

        if latest.url != baseline.url {
            return true
        }

        if let latestCreatedAt = latest.createdAt {
            return latestCreatedAt >= startedAt
        }

        return latest.createdAt != baseline.createdAt
    }
}

// MARK: - Railway Info

private struct RailwayInfo {
    let serviceName: String
    let url: String
    let createdAt: Date?
}
