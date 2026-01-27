import Foundation

/// Project file management service (MongoDB-backed files)
struct FileService {
    let client: APIClient

    /// List all files in the project
    func list(projectId: String) async throws -> FileListResponse {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/files")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(FileListResponse.self, data: data, response: response)
    }

    /// Read a file from the project
    func read(projectId: String, path: String) async throws -> ProjectFile {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/files/\(encodedPath)")
        let request = client.authorizedRequest(url: url)
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(ProjectFile.self, data: data, response: response)
    }

    /// Write a file to the project
    func write(projectId: String, path: String, content: String) async throws -> ProjectFile {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/files/\(encodedPath)")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct WriteFileRequest: Codable {
            let content: String
        }

        request.httpBody = try JSONEncoder().encode(WriteFileRequest(content: content))
        let (data, response) = try await NetworkSession.standard.data(for: request)
        return try client.decodeResponse(ProjectFile.self, data: data, response: response)
    }

    /// Delete a file from the project
    func delete(projectId: String, path: String) async throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/files/\(encodedPath)")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await NetworkSession.standard.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClient.APIError.invalidResponse
        }
    }
}
