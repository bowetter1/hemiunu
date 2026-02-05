import Foundation

/// Code generation service — download projects
struct CodeGenService {
    let client: APIClient

    /// Download project as ZIP
    func download(projectId: String) async throws -> URL {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/download")
        let request = client.authorizedRequest(url: url)

        let (data, response) = try await NetworkSession.standard.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClient.APIError.invalidResponse
        }

        // Save to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "project_\(projectId).zip"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        return fileURL
    }
}
