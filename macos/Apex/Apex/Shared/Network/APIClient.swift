import Foundation

/// Client for communicating with apex-server — pure network infrastructure
class APIClient {
    let baseURL: URL
    var authToken: String?
    private let decoder = JSONDecoder()

    init(baseURL: String = AppEnvironment.apiBaseURL) {
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
#if DEBUG
            debugAuthToken(token, url: url)
#endif
        }
        return request
    }

#if DEBUG
    private func debugAuthToken(_ token: String, url: URL) {
        let path = url.path.isEmpty ? "/" : url.path
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            print("[Auth] Authorization set for \(path), token format invalid")
            return
        }

        let payload = String(parts[1])
        guard let data = base64URLDecode(payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Auth] Authorization set for \(path), token payload unreadable")
            return
        }

        let aud = object["aud"] as? String ?? "n/a"
        let iss = object["iss"] as? String ?? "n/a"
        let sub = object["sub"] as? String ?? "n/a"
        let exp = object["exp"] as? TimeInterval ?? 0
        let expDate = exp > 0 ? Date(timeIntervalSince1970: exp) : nil
        let expText = expDate.map { ISO8601DateFormatter().string(from: $0) } ?? "n/a"

        print("[Auth] Authorization set for \(path), aud=\(aud), iss=\(iss), sub=\(sub), exp=\(expText)")
    }

    private func base64URLDecode(_ input: String) -> Data? {
        var base64 = input.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
    }
#endif

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
