import SwiftUI

/// Main design mode container
struct DesignView: View {
    @ObservedObject var client: APIClient
    @ObservedObject var wsClient: WebSocketManager
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedPageId: String?
    var onProjectCreated: ((String) -> Void)? = nil
    @State private var pageVersions: [PageVersion] = []
    @State private var lastKnownVersion: Int = 0

    // Find the selected page from sidebar
    var selectedPage: Page? {
        guard let pageId = selectedPageId else { return nil }
        return client.pages.first { $0.id == pageId }
    }

    var body: some View {
        if let project = client.currentProject {
            projectContent(project)
                .onChange(of: selectedPageId) { _, newPageId in
                    if let pageId = newPageId {
                        if let page = client.pages.first(where: { $0.id == pageId }) {
                            lastKnownVersion = page.currentVersion
                        }
                        loadVersions(projectId: project.id, pageId: pageId)
                    } else {
                        pageVersions = []
                    }
                }
                .onChange(of: client.pages) { _, newPages in
                    // Detect version changes by watching the pages array
                    guard let pageId = selectedPageId,
                          let page = newPages.first(where: { $0.id == pageId }) else { return }

                    if page.currentVersion != lastKnownVersion {
                        lastKnownVersion = page.currentVersion
                        loadVersions(projectId: project.id, pageId: pageId)
                    }
                }
                .onAppear {
                    // Load versions if page already selected
                    if let pageId = selectedPageId {
                        loadVersions(projectId: project.id, pageId: pageId)
                        // Track initial version
                        if let page = client.pages.first(where: { $0.id == pageId }) {
                            lastKnownVersion = page.currentVersion
                        }
                    }
                }
        } else {
            BriefBuilderView(client: client) { projectId in
                onProjectCreated?(projectId)
            }
        }
    }

    private func loadVersions(projectId: String, pageId: String) {
        Task {
            do {
                let versions = try await client.getPageVersions(projectId: projectId, pageId: pageId)
                await MainActor.run {
                    pageVersions = versions
                    if let page = client.pages.first(where: { $0.id == pageId }) {
                        lastKnownVersion = page.currentVersion
                    }
                }
            } catch {
                await MainActor.run {
                    pageVersions = []
                }
            }
        }
    }

    private func restoreVersion(project: Project, pageId: String, version: Int) {
        Task {
            do {
                let updated = try await client.restorePageVersion(
                    projectId: project.id,
                    pageId: pageId,
                    version: version
                )
                await MainActor.run {
                    // Update page in local list
                    if let index = client.pages.firstIndex(where: { $0.id == pageId }) {
                        client.pages[index] = updated
                    }
                }
            } catch {
                // Version restore failed
            }
        }
    }

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        // If a specific page is selected from sidebar, show it
        if let page = selectedPage {
            WebPreview(
                html: page.html,
                projectId: project.id,
                sidebarVisible: sidebarVisible,
                toolsPanelVisible: toolsPanelVisible,
                versions: pageVersions,
                currentVersion: page.currentVersion,
                onRestoreVersion: { version in
                    restoreVersion(project: project, pageId: page.id, version: version)
                }
            )
        } else {
            // Otherwise show based on project status
            switch project.status {
            case .brief:
                GeneratingView(message: "Searching for brand info...")

            case .clarification:
                GeneratingView(message: "Waiting for your input...")

            case .moodboard:
                // Moodboard is auto-selected, layouts are being generated
                // User can change moodboard from the right panel if needed
                GeneratingView(message: "Creating layouts...")

            case .layouts:
                // Show first layout by default, user can select others from sidebar
                if let firstLayout = client.pages.first(where: { $0.layoutVariant != nil }) {
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else {
                    GeneratingView(message: "Loading layouts...")
                }

            case .editing, .done:
                if let mainPage = client.pages.first(where: { $0.layoutVariant == nil }) {
                    WebPreview(html: mainPage.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else if let firstLayout = client.pages.first(where: { $0.layoutVariant != nil }) {
                    WebPreview(html: firstLayout.html, projectId: project.id, sidebarVisible: sidebarVisible, toolsPanelVisible: toolsPanelVisible)
                } else {
                    GeneratingView(message: "Loading...")
                }

            case .failed:
                ErrorView(message: project.errorMessage ?? "An error occurred")
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
                // Project creation failed
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
                // Page edit failed
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
