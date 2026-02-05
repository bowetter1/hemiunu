import Foundation

/// Code generation service — generate, edit, download projects
struct CodeGenService {
    let client: APIClient

    /// Generate a code project using AI
    func generate(projectId: String, projectType: String) async throws -> GenerateCodeResponse {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/generate-code")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600

        struct GenerateCodeRequest: Codable {
            let projectType: String

            enum CodingKeys: String, CodingKey {
                case projectType = "project_type"
            }
        }

        request.httpBody = try JSONEncoder().encode(GenerateCodeRequest(projectType: projectType))
        let (data, response) = try await NetworkSession.codeGeneration.data(for: request)
        return try client.decodeResponse(GenerateCodeResponse.self, data: data, response: response)
    }

    /// Edit code project with AI
    func edit(projectId: String, instruction: String) async throws -> String {
        let url = client.baseURL.appendingPathComponent("/api/v1/projects/\(projectId)/edit-code")
        var request = client.authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        struct EditCodeRequest: Codable {
            let instruction: String
        }

        request.httpBody = try JSONEncoder().encode(EditCodeRequest(instruction: instruction))

        struct EditCodeResponse: Codable {
            let response: String
        }

        let (data, response) = try await NetworkSession.aiGeneration.data(for: request)
        let result = try client.decodeResponse(EditCodeResponse.self, data: data, response: response)
        return result.response
    }

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
