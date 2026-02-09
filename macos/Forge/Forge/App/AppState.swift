import SwiftUI

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
@Observable
class AppState {
    static let shared = AppState()

    // MARK: - Appearance

    @ObservationIgnored
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .dark

    // MARK: - Navigation

    var currentMode: AppMode = .design
    var showFloatingChat: Bool = false
    var showSidebar: Bool = true
    var showResearchJSON: Bool = false

    // MARK: - Preview

    var selectedDevice: PreviewDevice = .laptop
    var pageVersions: [PageVersion] = []
    var currentVersionNumber: Int = 1

    // MARK: - Auth

    var isConnected: Bool = false
    var errorMessage: String?

    // MARK: - Selection

    var selectedProjectId: String?
    var selectedPageId: String?

    // MARK: - Domain Data

    var projects: [Project] = []
    var currentProject: Project?
    var pages: [Page] = []
    var localFiles: [LocalFileInfo] = []
    var localProjects: [LocalProject] = []

    // MARK: - AI

    var selectedProvider: AIProvider = .groq
    let glmService = CerebrasService(provider: .glm)
    let groqService = GroqService()
    let claudeService = ClaudeService()
    let togetherService = TogetherService()

    /// Returns the active AI service based on the selected provider
    var activeAIService: any AIService {
        resolveService(for: selectedProvider)
    }

    /// Resolve an AI service for any provider
    func resolveService(for provider: AIProvider) -> any AIService {
        switch provider {
        case .glm: return glmService
        case .groq: return groqService
        case .claude: return claudeService
        case .together: return togetherService
        }
    }

    /// Whether the Claude API key is configured (needed for Boss mode)
    var hasClaudeKey: Bool {
        guard let key = KeychainHelper.load(key: AIProvider.claude.keychainKey) else { return false }
        return !key.isEmpty
    }

    // MARK: - Services

    let workspace = LocalWorkspaceService.shared
    let authService = AuthService()

    // MARK: - View Models

    @ObservationIgnored
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
        await syncLocalVersionState(projectName: name)
    }

    /// URL for local project preview
    var localPreviewURL: URL?
    /// Token to force WebView refresh when file content changes
    var previewRefreshToken: UUID = UUID()

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

    // MARK: - Local Versioning

    func syncLocalVersionState(projectName: String) async {
        do {
            let initResult = try await workspace.ensureGitRepository(project: projectName)
            let commitResult = try await workspace.gitCommit(project: projectName, message: "Initial import")
            let versions = try await workspace.gitVersions(project: projectName)
            pageVersions = versions
            currentVersionNumber = versions.last?.version ?? 1
#if DEBUG
            print("[Versions][AppState] syncLocalVersionState project=\(projectName) init=\(initResult.exitCode) commit=\(commitResult.exitCode) count=\(versions.count) current=\(currentVersionNumber)")
#endif
        } catch {
#if DEBUG
            print("[Versions][AppState] syncLocalVersionState FAILED project=\(projectName) error=\(error.localizedDescription)")
#endif
            pageVersions = []
            currentVersionNumber = 1
        }
    }
}
