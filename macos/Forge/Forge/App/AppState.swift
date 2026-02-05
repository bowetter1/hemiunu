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
    @Published var errorMessage: String?

    // MARK: - Selection

    @Published var selectedProjectId: String?
    @Published var selectedPageId: String?
    @Published var showResearchJSON: Bool = false

    // MARK: - Domain Data

    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var pages: [Page] = []
    @Published var localFiles: [LocalFileInfo] = []
    @Published var localProjects: [LocalProject] = []

    // MARK: - AI

    @Published var selectedProvider: AIProvider = .groq
    let groqService = GroqService()
    let claudeService = ClaudeService()

    /// Returns the active AI service based on the selected provider
    var activeAIService: any AIService {
        switch selectedProvider {
        case .groq: return groqService
        case .claude: return claudeService
        }
    }

    // MARK: - Services

    let workspace = LocalWorkspaceService.shared
    let authService = AuthService()

    // MARK: - View Models

    lazy var chatViewModel = ChatViewModel(appState: self)

    // MARK: - Initialization

    private init() {}

    // MARK: - Auth

    func connect() async {
        refreshLocalProjects()

        if authService.isSignedIn {
            do {
                _ = try await authService.refreshToken()
            } catch {
                return
            }
            await didSignIn()
        }
    }

    /// Scan ~/Forge/projects/ for workspaces with HTML files
    func refreshLocalProjects() {
        localProjects = workspace.listHTMLWorkspaces()
    }

    /// Called after a successful Google Sign-In
    func didSignIn() async {
        isConnected = true
        errorMessage = nil
    }

    func logout() {
        authService.logout()
        isConnected = false
        selectedProjectId = nil
        currentProject = nil
        projects = []
        pages = []
    }

    // MARK: - Projects

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
        if let localName = localProjectName(from: id) {
            await loadLocalProject(name: localName, id: id)
            return
        }
    }

    /// Load a local project from ~/Forge/projects/<name>
    private func loadLocalProject(name: String, id: String) async {
        let projectPath = workspace.projectPath(name)
        guard FileManager.default.fileExists(atPath: projectPath.path) else { return }

        currentProject = Project.local(id: id, name: name)

        localFiles = workspace.listFiles(project: name)
        pages = workspace.loadPages(project: name)

        if let mainFile = workspace.findMainHTML(project: name) {
            selectedPageId = "local-page-\(name)/\(mainFile)"
        } else {
            selectedPageId = pages.first?.id
        }

        localPreviewURL = workspace.projectPath(name)
    }

    /// URL for local project preview
    @Published var localPreviewURL: URL?
    /// Token to force WebView refresh when file content changes
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
        pages = []
        localFiles = []
        selectedProjectId = nil
        selectedPageId = nil
        localPreviewURL = nil
        pageVersions = []
        currentVersionNumber = 1
    }

    // MARK: - Delegate-like methods for ChatViewModel

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
