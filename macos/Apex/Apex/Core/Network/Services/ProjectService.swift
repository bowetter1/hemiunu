import Foundation

/// Project management service — CRUD, clarification, moodboard, layouts, site generation
struct ProjectService {
    let client: APIClient

    /// Create a new project
    func create(brief: String, imageSource: String? = nil, config: GenerationConfig? = nil) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        struct CreateProjectRequest: Codable {
            let brief: String
            let imageSource: String?
            let config: GenerationConfig?

            enum CodingKeys: String, CodingKey {
                case brief
                case imageSource = "image_source"
                case config
            }
        }

        request.httpBody = try JSONEncoder().encode(CreateProjectRequest(brief: brief, imageSource: imageSource, config: config))
        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

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

    /// Send clarification answer and continue moodboard generation
    func clarify(projectId: String, answer: String) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/clarify")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        struct ClarifyRequest: Codable {
            let answer: String
        }

        request.httpBody = try JSONEncoder().encode(ClarifyRequest(answer: answer))
        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// Select a moodboard (1, 2, or 3) and start layout generation
    func selectMoodboard(projectId: String, variant: Int) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/select-moodboard")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SelectMoodboardRequest: Codable {
            let variant: Int
        }

        request.httpBody = try JSONEncoder().encode(SelectMoodboardRequest(variant: variant))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// Trigger layout generation after research is done
    func generate(projectId: String) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// Generate 3 layout alternatives (legacy)
    func generateLayouts(projectId: String) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate-layouts")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// Select a layout (1, 2, or 3)
    func selectLayout(projectId: String, variant: Int) async throws -> Project {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/select-layout")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SelectLayoutRequest: Codable {
            let variant: Int
        }

        request.httpBody = try JSONEncoder().encode(SelectLayoutRequest(variant: variant))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Project.self, data: data, response: response)
    }

    /// Get project logs
    func getLogs(projectId: String) async throws -> [LogEntry] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/logs")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse([LogEntry].self, data: data, response: response)
    }

    /// Generate a complete mini-site from a specific layout/hero page
    func generateSite(projectId: String, parentPageId: String, pages: [String]? = nil) async throws -> GenerateSiteResponse {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate-site")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        struct GenerateSiteRequest: Codable {
            let parentPageId: String
            let pages: [String]?

            enum CodingKeys: String, CodingKey {
                case parentPageId = "parent_page_id"
                case pages
            }
        }

        request.httpBody = try JSONEncoder().encode(GenerateSiteRequest(parentPageId: parentPageId, pages: pages))
        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        return try client.decodeResponse(GenerateSiteResponse.self, data: data, response: response)
    }
}
