import Foundation
import Combine

/// Client for communicating with apex-server
class ApexClient: ObservableObject {
    static let shared = ApexClient()

    @Published var isConnected = false
    @Published var currentSprint: Sprint?
    @Published var logs: [LogEntry] = []
    @Published var pendingQuestion: AIQuestion?
    @Published var previewHTML: String?
    @Published var sprintFiles: [String] = []

    // Projects API
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var projectLogs: [ProjectLog] = []
    @Published var pages: [Page] = []

    private var baseURL: URL
    private(set) var authToken: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()

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
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        await MainActor.run {
            self.authToken = response.access_token
        }

        return response.access_token
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
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        await MainActor.run {
            self.authToken = response.access_token
        }

        return response.access_token
    }

    /// Check if user is logged in
    var isLoggedIn: Bool {
        authToken != nil
    }

    /// Logout
    func logout() {
        authToken = nil
        currentSprint = nil
        logs = []
        pendingQuestion = nil
        disconnectWebSocket()
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

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        await MainActor.run {
            self.authToken = response.access_token
        }

        return response.access_token
    }

    // MARK: - REST API

    /// Create a new sprint
    func createSprint(task: String, team: String = "a-team") async throws -> Sprint {
        let url = baseURL.appendingPathComponent("/api/v1/sprints")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateSprintRequest(task: task, team: team)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let sprint = try JSONDecoder().decode(Sprint.self, from: data)

        await MainActor.run {
            self.currentSprint = sprint
            self.logs = []
        }

        return sprint
    }

    /// Get sprint status
    func getSprint(id: String) async throws -> Sprint {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(id)")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Sprint.self, from: data)
    }

    /// Get sprint logs
    func getLogs(sprintId: String, sinceId: Int = 0) async throws -> [LogEntry] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/sprints/\(sprintId)/logs"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "since_id", value: String(sinceId))]

        let request = authorizedRequest(url: components.url!)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct LogsResponse: Codable {
            let logs: [LogEntry]
            let total: Int
        }

        let response = try JSONDecoder().decode(LogsResponse.self, from: data)
        return response.logs
    }

    /// Get pending question
    func getPendingQuestion(sprintId: String) async throws -> AIQuestion? {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(sprintId)/question")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        // Server returns null if no pending question
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                return nil
            }
            return try JSONDecoder().decode(AIQuestion.self, from: data)
        }
        return nil
    }

    /// Answer a question
    func answerQuestion(sprintId: String, questionId: Int, answer: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(sprintId)/question/\(questionId)/answer")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct AnswerRequest: Codable {
            let answer: String
        }

        request.httpBody = try JSONEncoder().encode(AnswerRequest(answer: answer))
        let _ = try await URLSession.shared.data(for: request)

        await MainActor.run {
            self.pendingQuestion = nil
        }
    }

    /// Cancel a sprint
    func cancelSprint(id: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(id)/cancel")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        let _ = try await URLSession.shared.data(for: request)
    }

    /// Get file content from sprint
    func getFileContent(sprintId: String, path: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(sprintId)/files/\(path)")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct FileResponse: Codable {
            let path: String
            let content: String
        }

        let response = try JSONDecoder().decode(FileResponse.self, from: data)
        return response.content
    }

    /// List files in sprint directory
    func listFiles(sprintId: String) async throws -> [String] {
        let url = baseURL.appendingPathComponent("/api/v1/sprints/\(sprintId)/files")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct FilesResponse: Codable {
            let files: String  // Newline-separated list
        }

        let response = try JSONDecoder().decode(FilesResponse.self, from: data)
        return response.files.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: - WebSocket

    /// Connect to sprint WebSocket for real-time updates
    func connectWebSocket(sprintId: String, token: String) {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.path = "/api/v1/sprints/\(sprintId)/ws"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: components.url!)
        webSocketTask?.resume()

        isConnected = true
        receiveMessage()
    }

    /// Disconnect WebSocket
    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self?.receiveMessage()

            case .failure(let error):
                print("WebSocket error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        struct WSMessage: Codable {
            let type: String
            let data: AnyCodable?
        }

        do {
            let message = try JSONDecoder().decode(WSMessage.self, from: data)

            DispatchQueue.main.async {
                switch message.type {
                case "log":
                    if let logData = message.data?.value as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: logData),
                       let log = try? JSONDecoder().decode(LogEntry.self, from: jsonData) {
                        self.logs.append(log)
                    }

                case "status":
                    // Sprint status update
                    break

                case "question":
                    if let qData = message.data?.value as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: qData),
                       let question = try? JSONDecoder().decode(AIQuestion.self, from: jsonData) {
                        self.pendingQuestion = question
                    }

                case "pong":
                    break

                default:
                    print("Unknown WebSocket message type: \(message.type)")
                }
            }
        } catch {
            print("Failed to decode WebSocket message: \(error)")
        }
    }

    /// Send ping to keep connection alive
    func sendPing() {
        webSocketTask?.send(.string("ping")) { error in
            if let error = error {
                print("Ping error: \(error)")
            }
        }
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
        let (data, _) = try await URLSession.shared.data(for: request)
        let project = try JSONDecoder().decode(Project.self, from: data)

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
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Project.self, from: data)
    }

    /// List all user's projects
    func listProjects() async throws -> [Project] {
        let url = baseURL.appendingPathComponent("/api/v1/projects")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        let projects = try JSONDecoder().decode([Project].self, from: data)

        await MainActor.run {
            self.projects = projects
        }

        return projects
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
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Project.self, from: data)
    }

    /// Generate 3 layout alternatives
    func generateLayouts(projectId: String) async throws -> Project {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate-layouts")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Project.self, from: data)
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
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Project.self, from: data)
    }

    /// Get all pages for a project
    func getPages(projectId: String) async throws -> [Page] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([Page].self, from: data)
    }

    /// Get a specific page
    func getPage(projectId: String, pageId: String) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Page.self, from: data)
    }

    /// Edit a page with AI instruction
    func editPage(projectId: String, pageId: String, instruction: String) async throws -> Page {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/edit")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct EditPageRequest: Codable {
            let instruction: String
        }

        request.httpBody = try JSONEncoder().encode(EditPageRequest(instruction: instruction))
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Page.self, from: data)
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
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Page.self, from: data)
    }

    /// Get project logs
    func getProjectLogs(projectId: String) async throws -> [ProjectLog] {
        let url = baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/logs")
        let request = authorizedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([ProjectLog].self, from: data)
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}
