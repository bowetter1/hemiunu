import Foundation

/// Page management service — CRUD, edit, sync, versions
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

    /// Edit a page with AI instruction (legacy - returns full HTML)
    func edit(projectId: String, pageId: String, instruction: String) async throws -> Page {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/edit")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        struct EditPageRequest: Codable {
            let instruction: String
        }

        request.httpBody = try JSONEncoder().encode(EditPageRequest(instruction: instruction))
        let (data, response) = try await NetworkSession.aiEditing.data(for: request)
        return try client.decodeResponse(Page.self, data: data, response: response)
    }

    /// Get structured edit instructions (token-efficient)
    func structuredEdit(projectId: String, pageId: String, instruction: String, currentHtml: String) async throws -> StructuredEditResponse {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/structured-edit")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        struct StructuredEditRequest: Codable {
            let instruction: String
            let html: String
        }

        request.httpBody = try JSONEncoder().encode(StructuredEditRequest(instruction: instruction, html: currentHtml))
        let (data, response) = try await NetworkSession.aiEditing.data(for: request)
        return try client.decodeResponse(StructuredEditResponse.self, data: data, response: response)
    }

    /// Sync updated HTML back to server after local edits
    func sync(projectId: String, pageId: String, html: String) async throws -> Page {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages/\(pageId)/sync")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SyncPageRequest: Codable {
            let html: String
        }

        request.httpBody = try JSONEncoder().encode(SyncPageRequest(html: html))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Page.self, data: data, response: response)
    }

    /// Add a new page to project
    func add(projectId: String, name: String, description: String? = nil) async throws -> Page {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/pages")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct AddPageRequest: Codable {
            let name: String
            let description: String?
        }

        request.httpBody = try JSONEncoder().encode(AddPageRequest(name: name, description: description))
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
