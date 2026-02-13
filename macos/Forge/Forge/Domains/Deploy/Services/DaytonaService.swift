import Foundation

/// Thin API wrapper for Daytona sandbox operations.
/// The deployer agent calls these methods via tools.
enum DaytonaService {
    static let baseURL = "https://app.daytona.io/api"
    static let keychainKey = "forge.api.daytona"

    /// Check if API key is configured
    static var hasAPIKey: Bool {
        guard let key = KeychainHelper.load(key: keychainKey) else { return false }
        return !key.isEmpty
    }

    // MARK: - Sandbox Lifecycle

    /// Create a public sandbox, poll until it starts, return sandbox ID
    static func createSandbox(name: String) async throws -> String {
        let apiKey = try requireAPIKey()
        let url = try makeURL("\(baseURL)/sandbox")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": name,
            "target": "eu",
            "public": true,
            "auto_stop_interval": 0,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sandboxId = json["id"] as? String else {
            throw DaytonaError.invalidResponse("No sandbox ID in response")
        }

        // Poll until sandbox is running (up to 30s, check every 1s)
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if try await isSandboxRunning(id: sandboxId, apiKey: apiKey) {
                return sandboxId
            }
        }

        return sandboxId // Return anyway, agent can handle if not ready
    }

    /// Stop a sandbox
    static func stopSandbox(id: String) async throws {
        let apiKey = try requireAPIKey()
        let url = try makeURL("\(baseURL)/sandbox/\(id)/stop")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)
    }

    /// Start a stopped sandbox
    static func startSandbox(id: String) async throws {
        let apiKey = try requireAPIKey()
        let url = try makeURL("\(baseURL)/sandbox/\(id)/start")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)

        // Poll until running (up to 30s)
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            if try await isSandboxRunning(id: id, apiKey: apiKey) { return }
        }
    }

    /// Get sandbox state (started, stopped, archived, etc.)
    static func sandboxState(id: String) async -> String? {
        guard let apiKey = try? requireAPIKey(),
              let url = URL(string: "\(baseURL)/sandbox/\(id)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else { return nil }
        return state
    }

    // MARK: - File Operations

    /// Upload a single file (multipart form-data)
    static func uploadFile(sandboxId: String, remotePath: String, localData: Data) async throws {
        let apiKey = try requireAPIKey()
        let encodedPath = remotePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? remotePath
        let url = try makeURL("\(baseURL)/toolbox/\(sandboxId)/toolbox/files/upload?path=\(encodedPath)")

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"upload\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(localData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)
    }

    // MARK: - Execution

    /// Execute a command in the sandbox (sync, with timeout)
    static func exec(sandboxId: String, command: String, timeout: Int = 120) async throws -> (exitCode: Int, output: String) {
        let apiKey = try requireAPIKey()
        let url = try makeURL("\(baseURL)/toolbox/\(sandboxId)/toolbox/process/execute")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = TimeInterval(timeout + 10)

        let body: [String: Any] = [
            "command": "bash -c \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\"",
            "timeout": timeout,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DaytonaError.invalidResponse("Cannot parse exec response")
        }

        let exitCode = json["exitCode"] as? Int ?? json["code"] as? Int ?? -1
        let stdout = json["result"] as? String ?? json["output"] as? String ?? ""
        return (exitCode, stdout)
    }

    // MARK: - Preview

    /// Get the public preview URL for a port
    static func previewURL(sandboxId: String, port: Int) -> String {
        "https://\(port)-\(sandboxId).proxy.daytona.works"
    }

    // MARK: - Private

    private static func requireAPIKey() throws -> String {
        guard let key = KeychainHelper.load(key: keychainKey), !key.isEmpty else {
            throw DaytonaError.missingAPIKey
        }
        return key
    }

    private static func makeURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw DaytonaError.invalidResponse("Invalid URL: \(string)")
        }
        return url
    }

    private static func isSandboxRunning(id: String, apiKey: String) async throws -> Bool {
        let url = try makeURL("\(baseURL)/sandbox/\(id)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else { return false }
        return state == "started" || state == "running"
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw DaytonaError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Errors

enum DaytonaError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Daytona API key not configured. Add it in Deploy settings."
        case .httpError(let code, let body):
            return "Daytona API error \(code): \(body)"
        case .invalidResponse(let detail):
            return "Invalid Daytona response: \(detail)"
        }
    }
}
