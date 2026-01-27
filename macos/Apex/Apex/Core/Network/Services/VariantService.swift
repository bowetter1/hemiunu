import Foundation

/// Variant management service
struct VariantService {
    let client: APIClient

    /// Get all variants for a project (returns empty array if none exist or endpoint not available)
    func getAll(projectId: String) async throws -> [Variant] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)

        // Return empty array for 404 (no variants yet or endpoint not deployed)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return []
        }
        return try client.decodeResponse([Variant].self, data: data, response: response)
    }

    /// Create a new variant
    func create(projectId: String, name: String, moodboardIndex: Int) async throws -> Variant {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct CreateVariantRequest: Codable {
            let name: String
            let moodboard_index: Int
        }

        request.httpBody = try JSONEncoder().encode(CreateVariantRequest(name: name, moodboard_index: moodboardIndex))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(Variant.self, data: data, response: response)
    }

    /// Get pages for a specific variant
    func getPages(projectId: String, variantId: String) async throws -> [Page] {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/variants/\(variantId)/pages")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse([Page].self, data: data, response: response)
    }
}
