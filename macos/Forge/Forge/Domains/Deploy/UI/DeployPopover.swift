import SwiftUI

/// Deploy popover — API key setup or one-click deploy
struct DeployPopover: View {
    let appState: AppState
    let chatViewModel: ChatViewModel

    @State private var apiKey = ""
    @State private var selectedVersion = "v1"
    @State private var isDeploying = false
    @State private var deployURL: String?

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
        .frame(width: 260)
        .onAppear {
            selectedVersion = currentVersion
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
            Text("Deploy to Daytona")
                .font(.system(size: 12, weight: .semibold))

            if versions.count > 1 {
                Picker("Version", selection: $selectedVersion) {
                    ForEach(versions, id: \.self) { v in
                        Text(v).tag(v)
                    }
                }
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
                    Text(isDeploying ? "Deploying..." : "Deploy \(selectedVersion)")
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
            for _ in 0..<120 { // Poll for up to 2 minutes
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

    private func findDeployURL() -> String? {
        for message in chatViewModel.messages.reversed() {
            if let range = message.content.range(of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.works"#, options: .regularExpression) {
                return String(message.content[range])
            }
        }
        return nil
    }
}
