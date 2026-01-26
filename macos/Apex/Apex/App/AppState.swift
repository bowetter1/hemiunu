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
    @Published var errorMessage: String?

    // MARK: - Projects

    @Published var selectedProjectId: String?
    @Published var selectedVariantId: String?
    @Published var selectedPageId: String?

    // MARK: - Services

    let client = APIClient()
    let wsClient = WebSocketManager()

    // MARK: - Initialization

    private init() {}

    // MARK: - Auth

    func connect() async {
        do {
            _ = try await client.getDevToken()
            isConnected = true
            errorMessage = nil

            // Fetch existing projects
            _ = try await client.listProjects()
        } catch {
            errorMessage = "Cannot connect"
        }
    }

    func logout() {
        client.logout()
        isConnected = false
        selectedProjectId = nil
    }

    // MARK: - Projects

    private var connectedProjectId: String?
    private var loadProjectTask: Task<Void, Never>?

    func loadProject(id: String) async {
        do {
            let project = try await client.getProject(id: id)
            client.currentProject = project

            // Load variants
            let variants = try await client.getVariants(projectId: id)
            client.variants = variants

            // Load pages
            let pages = try await client.getPages(projectId: id)
            client.pages = pages

            // Auto-select first variant and its first page
            if let firstVariant = variants.first {
                selectedVariantId = firstVariant.id
                // Find first page in this variant
                if let firstPage = pages.first(where: { $0.variantId == firstVariant.id }) {
                    selectedPageId = firstPage.id
                }
            } else if !pages.isEmpty {
                // Fallback: layouts without variants - select first layout
                if let firstLayout = pages.first(where: { $0.layoutVariant != nil }) {
                    selectedPageId = firstLayout.id
                } else if let firstPage = pages.first {
                    selectedPageId = firstPage.id
                }
            }

            // Load logs
            let logs = try await client.getProjectLogs(projectId: id)
            client.projectLogs = logs

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
        client.currentProject = nil
        client.variants = []
        client.pages = []
        client.projectLogs = []
        selectedProjectId = nil
        selectedVariantId = nil
        selectedPageId = nil
        connectedProjectId = nil
        wsClient.disconnect()
    }
}
