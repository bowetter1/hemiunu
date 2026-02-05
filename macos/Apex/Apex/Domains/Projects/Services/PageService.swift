import Foundation

/// Page management service — read pages and versions for deployed projects
struct PageService {
    let client: APIClient

    /// Get all pages for a project
    func getAll(projectId: String) async throws -> [Page] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse([Page].self, data: data, response: response)
    }

    /// Get a specific page
    func get(projectId: String, pageId: String) async throws -> Page {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Page.self, data: data, response: response)
    }

    /// Get all versions of a page
    func getVersions(projectId: String, pageId: String) async throws -> [PageVersion] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/versions")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClient.APIError.invalidResponse
        }

        // Handle 404 - no versions yet is normal
        if httpResponse.statusCode == 404 {
            return []
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClient.APIError.server(status: httpResponse.statusCode, message: client.errorMessage(from: data))
        }

        return try client.decodeResponse([PageVersion].self, data: data, response: response)
    }

    /// Restore a page to a specific version
    func restoreVersion(projectId: String, pageId: String, version: Int) async throws -> Page {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/restore")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct RestoreVersionRequest: Codable {
            let version: Int
        }

        request.httpBody = try JSONEncoder().encode(RestoreVersionRequest(version: version))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Page.self, data: data, response: response)
    }
}
