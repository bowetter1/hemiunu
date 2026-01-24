import SwiftUI

/// Main design mode container
struct DesignView: View {
    @ObservedObject var client: APIClient
    @ObservedObject var wsClient: WebSocketManager
    var sidebarVisible: Bool = true
    @State private var selectedMoodboardVariant: Int? = nil
    @State private var selectedLayoutVariant: Int? = nil

    var body: some View {
        if let project = client.currentProject {
            projectContent(project)
        } else {
            WelcomeView()
        }
    }

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        switch project.status {
        case .brief:
            GeneratingView(message: "Generating moodboard...")

        case .moodboard:
            if !project.moodboards.isEmpty {
                MoodboardPicker(
                    moodboards: project.moodboards,
                    selectedVariant: $selectedMoodboardVariant
                ) {
                    selectMoodboard(project: project)
                }
            } else {
                GeneratingView(message: "Loading moodboards...")
            }

        case .layouts:
            LayoutCarousel(
                pages: client.pages,
                selectedVariant: $selectedLayoutVariant
            ) {
                selectLayout(project: project)
            }

        case .editing, .done:
            if let mainPage = client.pages.first(where: { $0.layoutVariant == nil }) {
                WebPreview(html: mainPage.html, sidebarVisible: sidebarVisible)
            } else {
                GeneratingView(message: "Loading...")
            }

        case .failed:
            ErrorView(message: project.errorMessage ?? "An error occurred")
        }
    }

    private func selectMoodboard(project: Project) {
        guard let variant = selectedMoodboardVariant else { return }
        Task {
            do {
                let updated = try await client.selectMoodboard(projectId: project.id, variant: variant)
                await MainActor.run {
                    client.currentProject = updated
                }
            } catch {
                print("Failed to select moodboard: \(error)")
            }
        }
    }

    private func selectLayout(project: Project) {
        guard let variant = selectedLayoutVariant else { return }
        Task {
            do {
                let updated = try await client.selectLayout(projectId: project.id, variant: variant)
                await MainActor.run {
                    client.currentProject = updated
                }
                let pages = try await client.getPages(projectId: project.id)
                await MainActor.run {
                    client.pages = pages
                }
            } catch {
                print("Failed to select layout: \(error)")
            }
        }
    }
}

// MARK: - Design Command Bar

struct DesignCommandBar: View {
    @ObservedObject var client: APIClient
    @State private var commandText = ""

    var body: some View {
        CommandBar(
            text: $commandText,
            placeholder: placeholderText
        ) {
            processCommand()
        }
    }

    private var placeholderText: String {
        if let project = client.currentProject {
            switch project.status {
            case .editing, .done:
                return "Describe what you want to change..."
            default:
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    private func processCommand() {
        guard !commandText.isEmpty else { return }
        let text = commandText
        commandText = ""

        if let project = client.currentProject,
           project.status == .editing || project.status == .done {
            editCurrentPage(instruction: text)
        } else {
            createProject(brief: text)
        }
    }

    private func createProject(brief: String) {
        Task {
            do {
                _ = try await client.createProject(brief: brief)
            } catch {
                print("Failed to create project: \(error)")
            }
        }
    }

    private func editCurrentPage(instruction: String) {
        guard let project = client.currentProject,
              let page = client.pages.first(where: { $0.layoutVariant == nil }) else { return }

        Task {
            do {
                let updated = try await client.editPage(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction
                )
                await MainActor.run {
                    if let index = client.pages.firstIndex(where: { $0.id == page.id }) {
                        client.pages[index] = updated
                    }
                }
            } catch {
                print("Failed to edit page: \(error)")
            }
        }
    }
}

// MARK: - Design State Views

/// Welcome view shown when no project is selected
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Welcome to Apex")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Describe your website to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading view with a message shown during generation
struct GeneratingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error view showing an error message
struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
