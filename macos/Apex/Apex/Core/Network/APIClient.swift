import Foundation
import Combine

/// Client for communicating with apex-server
class APIClient: ObservableObject {
    static let shared = APIClient()

    // Projects API
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var projectLogs: [LogEntry] = []
    @Published var variants: [Variant] = []
    @Published var pages: [Page] = []

    private var baseURL: URL
    private(set) var authToken: String?
    private let decoder = JSONDecoder()

    init(baseURL: String = "https://apex-server-production-a540.up.railway.app") {
        self.baseURL = URL(string: baseURL)!
    }

    // MARK: - Configuration

    func configure(baseURL: String, token: String? = nil) {
        self.baseURL = URL(string: baseURL)!
        self.authToken = token
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case server(status: Int, message: String)
        case decoding(message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case .server(let status, let message):
                return "Server error (\(status)): \(message)"
            case .decoding(let message):
                return "Failed to decode response: \(message)"
            }
        }
    }

    private func errorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = object["detail"] as? String {
                return detail
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(status: httpResponse.statusCode, message: errorMessage(from: data))
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let message = errorMessage(from: data)
            throw APIError.decoding(message: message.isEmpty ? error.localizedDescription : message)
        }
    }

    private func assertSuccess(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(status: httpResponse.statusCode, message: errorMessage(from: data))
        }
    }

    // MARK: - Auth

    /// Login and get access token
    func login(email: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/api/v1/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct LoginRequest: Codable {
            let email: String
            let password: String
        }

        struct TokenResponse: Codable {
            let access_token: String
            let token_type: String
        }

        request.httpBody = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        let (data, response) = try await URLSession.shared.data(for: request)
        let tokenResponse = try decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            self.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    /// Register new user and tenant
    func register(email: String, password: String, name: String, tenantName: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/api/v1/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct RegisterRequest: Codable {
            let email: String
            let password: String
            let name: String
            let tenant_name: String
        }

        struct TokenResponse: Codable {
            let access_token: String
            let token_type: String
        }

        let body = RegisterRequest(email: email, password: password, name: name, tenant_name: tenantName)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let tokenResponse = try decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            self.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    /// Check if user is logged in
    var isLoggedIn: Bool {
        authToken != nil
    }

    /// Logout
    func logout() {
        authToken = nil
        currentProject = nil
        projects = []
        projectLogs = []
        pages = []
    }

    /// Get dev token (skips login for development)
    func getDevToken() async throws -> String {
        let url = baseURL.appendingPathComponent("/api/v1/auth/dev-token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        struct TokenResponse: Codable {
            let access_token: String
            let token_type: String
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let tokenResponse = try decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            self.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    // MARK: - Projects API

    /// Create a new project
    func createProject(brief: String) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct CreateProjectRequest: Codable {
            let brief: String
        }

        request.httpBody = try JSONEncoder().encode(CreateProjectRequest(brief: brief))
        let (data, response) = try await URLSession.shared.data(for: request)
        let project = try decodeResponse(Project.self, data: data, response: response)

        await MainActor.run {
            self.currentProject = project
            self.projectLogs = []
            self.pages = []
            // Add to projects list
            self.projects.insert(project, at: 0)
        }

        return project
    }

    /// Get project by ID
    func getProject(id: String) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(id)")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Project.self, data: data, response: response)
    }

    /// List all user's projects
    func listProjects() async throws -> [Project] {
        let url = baseURL.appendingPathComponent("/api/v1/projects")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        let projects = try decodeResponse([Project].self, data: data, response: response)

        await MainActor.run {
            self.projects = projects
        }

        return projects
    }

    /// Send clarification answer and continue moodboard generation
    func clarifyProject(projectId: String, answer: String) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/clarify")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct ClarifyRequest: Codable {
            let answer: String
        }

        request.httpBody = try JSONEncoder().encode(ClarifyRequest(answer: answer))
        let (data, response) = try await URLSession.shared.data(for: request)
        let project = try decodeResponse(Project.self, data: data, response: response)

        await MainActor.run {
            self.currentProject = project
        }

        return project
    }

    /// Select a moodboard (1, 2, or 3) and start layout generation
    func selectMoodboard(projectId: String, variant: Int) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/select-moodboard")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SelectMoodboardRequest: Codable {
            let variant: Int
        }

        request.httpBody = try JSONEncoder().encode(SelectMoodboardRequest(variant: variant))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Project.self, data: data, response: response)
    }

    /// Generate 3 layout alternatives
    func generateLayouts(projectId: String) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate-layouts")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Project.self, data: data, response: response)
    }

    /// Select a layout (1, 2, or 3)
    func selectLayout(projectId: String, variant: Int) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/select-layout")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SelectLayoutRequest: Codable {
            let variant: Int
        }

        request.httpBody = try JSONEncoder().encode(SelectLayoutRequest(variant: variant))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Project.self, data: data, response: response)
    }

    // MARK: - Variants

    /// Get all variants for a project
    func getVariants(projectId: String) async throws -> [Variant] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse([Variant].self, data: data, response: response)
    }

    /// Create a new variant
    func createVariant(projectId: String, name: String, moodboardIndex: Int) async throws -> Variant {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct CreateVariantRequest: Codable {
            let name: String
            let moodboard_index: Int
        }

        request.httpBody = try JSONEncoder().encode(CreateVariantRequest(name: name, moodboard_index: moodboardIndex))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Variant.self, data: data, response: response)
    }

    /// Get pages for a specific variant
    func getVariantPages(projectId: String, variantId: String) async throws -> [Page] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants/\(variantId)/pages")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse([Page].self, data: data, response: response)
    }

    // MARK: - Pages

    /// Get all pages for a project
    func getPages(projectId: String) async throws -> [Page] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse([Page].self, data: data, response: response)
    }

    /// Get a specific page
    func getPage(projectId: String, pageId: String) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Page.self, data: data, response: response)
    }

    /// Edit a page with AI instruction (legacy - returns full HTML)
    func editPage(projectId: String, pageId: String, instruction: String) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/edit")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct EditPageRequest: Codable {
            let instruction: String
        }

        request.httpBody = try JSONEncoder().encode(EditPageRequest(instruction: instruction))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Page.self, data: data, response: response)
    }

    /// Get structured edit instructions (token-efficient!)
    func getStructuredEdit(projectId: String, pageId: String, instruction: String, currentHtml: String) async throws -> StructuredEditResponse {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/structured-edit")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct StructuredEditRequest: Codable {
            let instruction: String
            let html: String
        }

        request.httpBody = try JSONEncoder().encode(StructuredEditRequest(instruction: instruction, html: currentHtml))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(StructuredEditResponse.self, data: data, response: response)
    }

    /// Sync updated HTML back to server after local edits
    func syncPage(projectId: String, pageId: String, html: String) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/sync")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SyncPageRequest: Codable {
            let html: String
        }

        request.httpBody = try JSONEncoder().encode(SyncPageRequest(html: html))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Page.self, data: data, response: response)
    }

    /// Add a new page to project
    func addPage(projectId: String, name: String, description: String? = nil) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct AddPageRequest: Codable {
            let name: String
            let description: String?
        }

        request.httpBody = try JSONEncoder().encode(AddPageRequest(name: name, description: description))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Page.self, data: data, response: response)
    }

    /// Get project logs
    func getProjectLogs(projectId: String) async throws -> [LogEntry] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/logs")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse([LogEntry].self, data: data, response: response)
    }

    /// Delete a project
    func deleteProject(projectId: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)")
        var request = authorizedRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        try assertSuccess(data: data, response: response)

        await MainActor.run {
            // Remove from local list
            self.projects.removeAll { $0.id == projectId }
            // Clear current if it was the deleted one
            if self.currentProject?.id == projectId {
                self.currentProject = nil
                self.pages = []
                self.projectLogs = []
            }
        }
    }

    // MARK: - Page Versions

    /// Get all versions of a page
    func getPageVersions(projectId: String, pageId: String) async throws -> [PageVersion] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/versions")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle 404 - no versions yet is normal
        if httpResponse.statusCode == 404 {
            return []
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(status: httpResponse.statusCode, message: errorMessage(from: data))
        }

        return try decodeResponse([PageVersion].self, data: data, response: response)
    }

    /// Restore a page to a specific version
    func restorePageVersion(projectId: String, pageId: String, version: Int) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/restore")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct RestoreVersionRequest: Codable {
            let version: Int
        }

        request.httpBody = try JSONEncoder().encode(RestoreVersionRequest(version: version))
        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(Page.self, data: data, response: response)
    }
}
