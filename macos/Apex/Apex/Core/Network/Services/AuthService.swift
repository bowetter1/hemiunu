import Foundation

/// Authentication service — login, register, dev-token, logout
struct AuthService {
    let client: APIClient

    private struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
    }

    /// Login and get access token
    func login(email: String, password: String) async throws -> String {
        let url = client.baseURL.appendingPathComponent("/api/v1/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct LoginRequest: Codable {
            let email: String
            let password: String
        }

        request.httpBody = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        let tokenResponse = try client.decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            client.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    /// Register new user and tenant
    func register(email: String, password: String, name: String, tenantName: String) async throws -> String {
        let url = client.baseURL.appendingPathComponent("/api/v1/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct RegisterRequest: Codable {
            let email: String
            let password: String
            let name: String
            let tenant_name: String
        }

        let body = RegisterRequest(email: email, password: password, name: name, tenant_name: tenantName)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        let tokenResponse = try client.decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            client.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    /// Get dev token (skips login for development)
    func getDevToken() async throws -> String {
        let url = client.baseURL.appendingPathComponent("/api/v1/auth/dev-token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await NetworkSession.standard.data(for: request)
        let tokenResponse = try client.decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            client.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    /// Logout — clear token
    func logout() {
        client.authToken = nil
    }
}
