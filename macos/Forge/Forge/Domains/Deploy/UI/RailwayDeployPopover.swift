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

    private var hasKey: Bool { RailwayAPIService.hasAPIKey }

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
            loadRailwayInfo()
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
                if let builder = currentBuilderName {
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
        isDeploying = true
        chatViewModel.sendMessage("Deploy version \(selectedVersion) to Railway")

        // Poll chat messages for Railway URL
        Task {
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let url = findRailwayURL() {
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

    private func loadRailwayInfo() {
        let projectName = currentProjectName
        guard !projectName.isEmpty else { return }
        let file = appState.workspace.projectPath(projectName).appendingPathComponent("railway.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serviceName = json["service_name"] as? String,
              let url = json["url"] as? String else { return }

        var createdAt: Date?
        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr)
        }

        savedRailway = RailwayInfo(serviceName: serviceName, url: url, createdAt: createdAt)
    }

    private func findRailwayURL() -> String? {
        for message in chatViewModel.messages.reversed() {
            if let range = message.content.range(of: #"https://[\w-]+-production\.up\.railway\.app"#, options: .regularExpression) {
                return String(message.content[range])
            }
        }
        return nil
    }
}

// MARK: - Railway Info

private struct RailwayInfo {
    let serviceName: String
    let url: String
    let createdAt: Date?
}
