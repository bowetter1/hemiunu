import Foundation

/// Client for communicating with apex-server — pure network infrastructure
class APIClient {
    let baseURL: URL
    var authToken: String?
    private let decoder = JSONDecoder()

    init(baseURL: String = "https://apex-server-production-a540.up.railway.app") {
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://localhost:8000")!
    }

    // MARK: - Configuration

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    var isLoggedIn: Bool {
        authToken != nil
    }

    // MARK: - Domain Services

    lazy var auth = AuthService(client: self)
    lazy var projectService = ProjectService(client: self)
    lazy var pageService = PageService(client: self)
    lazy var variantService = VariantService(client: self)
    lazy var fileService = FileService(client: self)
    lazy var codeGen = CodeGenService(client: self)

    // MARK: - Shared Infrastructure (used by services)

    func authorizedRequest(url: URL) -> URLRequest {
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

    func errorMessage(from data: Data) -> String {
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

    func decodeResponse<T: Decodable>(_ type: T.Type, data: Data, response: URLResponse) throws -> T {
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

    func assertSuccess(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(status: httpResponse.statusCode, message: errorMessage(from: data))
        }
    }
}
