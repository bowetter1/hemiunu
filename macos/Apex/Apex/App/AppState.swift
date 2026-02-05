import SwiftUI
import Combine

/// App navigation modes
enum AppMode: String, CaseIterable {
    case design = "Design"
    case code = "Code"
}

/// App appearance mode
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// Enable AppStorage support for AppearanceMode
extension AppearanceMode: RawRepresentable {
    init?(rawValue: String) {
        switch rawValue {
        case "system": self = .system
        case "light": self = .light
        case "dark": self = .dark
        default: self = .dark
        }
    }
}

/// Global app state - single source of truth
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Appearance

    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .dark

    // MARK: - Navigation

    @Published var currentMode: AppMode = .design
    @Published var showSidebar: Bool = true
    @Published var showFloatingChat: Bool = false

    // MARK: - Preview

    @Published var selectedDevice: PreviewDevice = .desktop
    @Published var pageVersions: [PageVersion] = []
    @Published var currentVersionNumber: Int = 1

    // MARK: - Auth

    @Published var isConnected: Bool = false
    @Published var isPendingApproval: Bool = false
    @Published var errorMessage: String?

    // MARK: - Selection

    @Published var selectedProjectId: String?
    @Published var selectedVariantId: String?
    @Published var selectedPageId: String?
    @Published var showResearchJSON: Bool = false

    // MARK: - Domain Data (migrated from APIClient)

    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var projectLogs: [LogEntry] = []
    @Published var variants: [Variant] = []
    @Published var pages: [Page] = []
    @Published var localFiles: [LocalFileInfo] = []
    @Published var localProjects: [LocalProject] = []

    // MARK: - Services

    let client = APIClient()
    let wsClient = WebSocketManager()
    let workspace = LocalWorkspaceService.shared
    let cli = CLIService.shared

    // MARK: - View Models

    lazy var chatViewModel = ChatViewModel(appState: self)

    // MARK: - Initialization

    private init() {}

    // MARK: - Auth

    func connect() async {
        // Scan local workspaces (available even before sign-in)
        refreshLocalProjects()

        // Try to restore existing Firebase session
        if client.auth.isSignedIn {
            do {
                _ = try await client.auth.refreshToken()
            } catch {
                return // Token refresh failed — show LoginView
            }
            await didSignIn()
        }
        // Otherwise: show LoginView (no auto-connect)
    }

    /// Scan ~/Apex/projects/ for workspaces with HTML files
    func refreshLocalProjects() {
        localProjects = workspace.listHTMLWorkspaces()
    }

    /// Called after a successful Google Sign-In
    func didSignIn() async {
        do {
            isConnected = true
            errorMessage = nil
            isPendingApproval = false

            let fetchedProjects = try await client.projectService.list()
            projects = fetchedProjects
        } catch let error as APIClient.APIError {
            if case .server(let status, _) = error, status == 403 {
                isPendingApproval = true
                isConnected = false
            } else {
                errorMessage = error.localizedDescription
                isConnected = false
            }
#if DEBUG
            print("[Auth] didSignIn() failed: \(error.localizedDescription)")
#endif
        } catch {
            errorMessage = error.localizedDescription
            isConnected = false
#if DEBUG
            print("[Auth] didSignIn() failed: \(error.localizedDescription)")
#endif
        }
    }

    func logout() {
        client.auth.logout()
        isConnected = false
        selectedProjectId = nil
        currentProject = nil
        projects = []
        projectLogs = []
        pages = []
        variants = []
    }

    // MARK: - Projects

    private var connectedProjectId: String?
    private var loadProjectTask: Task<Void, Never>?

    /// Check if a project ID refers to a local project
    var isLocalProject: Bool {
        selectedProjectId?.hasPrefix("local:") == true
    }

    /// Extract the local project name from a "local:name" ID
    func localProjectName(from id: String) -> String? {
        guard id.hasPrefix("local:") else { return nil }
        return String(id.dropFirst(6))
    }

    func loadProject(id: String) async {
        // Handle local projects (local:projectName)
        if let localName = localProjectName(from: id) {
            await loadLocalProject(name: localName, id: id)
            return
        }

        do {
            let project = try await client.projectService.get(id: id)
            currentProject = project

            // Load variants
            let loadedVariants = try await client.variantService.getAll(projectId: id)
            variants = loadedVariants

            // Load pages
            let loadedPages = try await client.pageService.getAll(projectId: id)
            pages = loadedPages

            // Auto-select first variant and its first page
            if let firstVariant = loadedVariants.first {
                selectedVariantId = firstVariant.id
                if let firstPage = loadedPages.first(where: { $0.variantId == firstVariant.id }) {
                    selectedPageId = firstPage.id
                }
            } else if !loadedPages.isEmpty {
                if let firstLayout = loadedPages.first(where: { $0.layoutVariant != nil }) {
                    selectedPageId = firstLayout.id
                } else if let firstPage = loadedPages.first {
                    selectedPageId = firstPage.id
                }
            }

            // Load logs
            let logs = try await client.projectService.getLogs(projectId: id)
            projectLogs = logs

            // Connect WebSocket only if not already connected to this project
            if connectedProjectId != id, let token = client.authToken {
                connectedProjectId = id
                wsClient.connect(projectId: id, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load a local project from ~/Apex/projects/<name>
    private func loadLocalProject(name: String, id: String) async {
        let projectPath = workspace.projectPath(name)
        guard FileManager.default.fileExists(atPath: projectPath.path) else { return }

        currentProject = Project.local(id: id, name: name)

        // Populate file list for code mode sidebar
        localFiles = workspace.listFiles(project: name)

        // Create pages from proposal HTML files (research artifacts at root are excluded)
        pages = workspace.loadPages(project: name)

        // Select the main HTML file
        if let mainFile = workspace.findMainHTML(project: name) {
            selectedPageId = "local-page-\(name)/\(mainFile)"
        } else {
            selectedPageId = pages.first?.id
        }

        variants = []
        projectLogs = []
        localPreviewURL = workspace.projectPath(name)
    }

    /// URL for local project preview (set when loading local projects)
    @Published var localPreviewURL: URL?
    /// Token to force WebView refresh when file content changes but URL stays the same
    @Published var previewRefreshToken: UUID = UUID()


    func scheduleLoadProject(id: String, delayMilliseconds: UInt64 = 300) {
        loadProjectTask?.cancel()
        loadProjectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadProject(id: id)
        }
    }

    func clearCurrentProject() {
        currentProject = nil
        variants = []
        pages = []
        localFiles = []
        projectLogs = []
        selectedProjectId = nil
        selectedVariantId = nil
        selectedPageId = nil
        localPreviewURL = nil
        pageVersions = []
        currentVersionNumber = 1
        connectedProjectId = nil
        wsClient.disconnect()
    }

}

// MARK: - BossCoordinatorDelegate

extension AppState: BossCoordinatorDelegate {
    func setSelectedProjectId(_ id: String?) {
        selectedProjectId = id
    }

    func setLocalFiles(_ files: [LocalFileInfo]) {
        localFiles = files
    }

    func setPages(_ newPages: [Page]) {
        pages = newPages
    }

    func setSelectedPageId(_ id: String?) {
        selectedPageId = id
    }

    func setLocalPreviewURL(_ url: URL?) {
        localPreviewURL = url
    }

    func refreshPreview() {
        previewRefreshToken = UUID()
    }
}
