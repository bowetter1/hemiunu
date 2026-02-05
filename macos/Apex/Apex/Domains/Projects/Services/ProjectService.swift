import Foundation

/// Project management service — CRUD operations for deployed projects
struct ProjectService {
    let client: APIClient

    /// Get project by ID
    func get(id: String) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(id)")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// List all user's projects
    func list() async throws -> [Project] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse([Project].self, data: data, response: response)
    }

    /// Delete a project
    func delete(projectId: String) async throws {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await NetworkSession.standard.data(for: request)
        try client.assertSuccess(data: data, response: response)
    }

    /// Get project logs
    func getLogs(projectId: String) async throws -> [LogEntry] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/logs")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse([LogEntry].self, data: data, response: response)
    }
}
