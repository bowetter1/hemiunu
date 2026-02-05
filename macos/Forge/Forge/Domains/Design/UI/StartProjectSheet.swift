import SwiftUI
import UniformTypeIdentifiers

struct StartProjectSheet: View {
    @Binding var isPresented: Bool
    let onProjectCreated: (String) -> Void

    @State private var projectName = ""
    @State private var briefText: String
    @State private var websiteURL = ""
    @State private var isCreating = false

    @EnvironmentObject private var appState: AppState

    init(isPresented: Binding<Bool>, initialBrief: String = "", onProjectCreated: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self._briefText = State(initialValue: initialBrief)
        self.onProjectCreated = onProjectCreated
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Start Project")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isCreating)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Project name
                    sectionLabel("Project Name", icon: "tag")
                    TextField("e.g. My Café", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    // Brief
                    sectionLabel("Description", icon: "text.alignleft")
                    TextField("What do you want to build?", text: $briefText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(3...5)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    // URL
                    sectionLabel("Reference URL (optional)", icon: "link")
                    TextField("https://example.com", text: $websiteURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(action: createProject) {
                    HStack(spacing: 6) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        Text(isCreating ? "Creating..." : "Create")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(canCreate ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate || isCreating)
            }
            .padding()
        }
        .frame(width: 420, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !briefText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
    }

    // MARK: - Actions

    private func createProject() {
        guard canCreate else { return }
        isCreating = true

        var prompt = briefText
        if !websiteURL.isEmpty {
            prompt += "\n\nReference website: \(websiteURL)"
        }

        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmedName.isEmpty
            ? "project-\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: " ", with: ""))"
            : trimmedName.lowercased().replacingOccurrences(of: " ", with: "-")

        // Create project directory and brief
        do {
            _ = try appState.workspace.createProject(name: safeName)
            try appState.workspace.writeFile(project: safeName, path: "brief.md", content: "## Project\n\n\(prompt)")

            // Init git
            Task {
                _ = try? await appState.workspace.gitInit(project: safeName)
            }
        } catch {
            #if DEBUG
            print("[StartProject] Error: \(error)")
            #endif
        }

        let projectId = "local:\(safeName)"
        isPresented = false

        // Send the brief to the chat
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            appState.setSelectedProjectId(projectId)
            appState.chatViewModel.sendMessage(prompt)
        }
    }
}
