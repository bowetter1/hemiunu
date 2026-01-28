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

    // MARK: - Services

    let client = APIClient()
    let wsClient = WebSocketManager()

    // MARK: - View Models

    lazy var chatViewModel = ChatViewModel(appState: self)

    // MARK: - Initialization

    private init() {}

    // MARK: - Auth

    func connect() async {
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

    func loadProject(id: String) async {
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
            // Project load failed
        }
    }

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
        projectLogs = []
        selectedProjectId = nil
        selectedVariantId = nil
        selectedPageId = nil
        connectedProjectId = nil
        wsClient.disconnect()
    }
}
