import Foundation

/// Railway HTTP API wrapper (GraphQL + REST upload).
/// Replaces the CLI-based RailwayService — works with just an API token.
enum RailwayAPIService {
    static let graphqlURL = "https://backboard.railway.com/graphql/v2"
    static let keychainKey = "forge.api.railway"

    /// Check if API key is configured
    static var hasAPIKey: Bool {
        guard let key = KeychainHelper.load(key: keychainKey) else { return false }
        return !key.isEmpty
    }

    // MARK: - Project

    /// Create a Railway project. Returns (projectId, environmentId).
    static func createProject(name: String) async throws -> (projectId: String, environmentId: String) {
        let query = """
        mutation($name: String!) {
          projectCreate(input: { name: $name }) {
            id
            environments {
              edges {
                node { id }
              }
            }
          }
        }
        """
        let result = try await graphql(query, variables: ["name": name])

        guard let projectCreate = result["projectCreate"] as? [String: Any],
              let projectId = projectCreate["id"] as? String,
              let environments = projectCreate["environments"] as? [String: Any],
              let edges = environments["edges"] as? [[String: Any]],
              let firstEdge = edges.first,
              let node = firstEdge["node"] as? [String: Any],
              let environmentId = node["id"] as? String else {
            throw RailwayAPIError.invalidResponse("Cannot parse projectCreate response")
        }

        return (projectId, environmentId)
    }

    // MARK: - Service

    /// Create a service inside a project. Returns serviceId.
    static func createService(projectId: String, name: String) async throws -> String {
        let query = """
        mutation($projectId: String!, $name: String!) {
          serviceCreate(input: { projectId: $projectId, name: $name }) {
            id
          }
        }
        """
        let result = try await graphql(query, variables: ["projectId": projectId, "name": name])

        guard let serviceCreate = result["serviceCreate"] as? [String: Any],
              let serviceId = serviceCreate["id"] as? String else {
            throw RailwayAPIError.invalidResponse("Cannot parse serviceCreate response")
        }

        return serviceId
    }

    // MARK: - Upload & Deploy

    /// Upload a tar.gz and trigger a deploy. Returns deploymentId.
    static func uploadAndDeploy(projectId: String, environmentId: String, serviceId: String, tarball: Data) async throws -> String {
        let apiKey = try requireAPIKey()
        let urlString = "https://backboard.railway.com/project/\(projectId)/environment/\(environmentId)/up?serviceId=\(serviceId)"
        guard let url = URL(string: urlString) else {
            throw RailwayAPIError.invalidResponse("Bad upload URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/gzip", forHTTPHeaderField: "Content-Type")
        request.httpBody = tarball
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)

        // Response may contain deploymentId
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deploymentId = json["deploymentId"] as? String ?? json["id"] as? String {
            return deploymentId
        }

        // Some endpoints return plain text or different shapes — extract what we can
        let body = String(data: data, encoding: .utf8) ?? ""
        if let range = body.range(of: #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#, options: .regularExpression) {
            return String(body[range])
        }

        throw RailwayAPIError.invalidResponse("No deploymentId in upload response: \(body.prefix(200))")
    }

    // MARK: - Domain

    /// Create a public service domain. Returns the full URL (https://...).
    static func createDomain(serviceId: String, environmentId: String) async throws -> String {
        let query = """
        mutation($serviceId: String!, $environmentId: String!) {
          serviceDomainCreate(input: { serviceId: $serviceId, environmentId: $environmentId }) {
            domain
          }
        }
        """
        let result = try await graphql(query, variables: ["serviceId": serviceId, "environmentId": environmentId])

        guard let domainCreate = result["serviceDomainCreate"] as? [String: Any],
              let domain = domainCreate["domain"] as? String else {
            throw RailwayAPIError.invalidResponse("Cannot parse serviceDomainCreate response")
        }

        return domain.hasPrefix("http") ? domain : "https://\(domain)"
    }

    // MARK: - Deployment Status

    /// Query deployment status. Returns status string (e.g. "SUCCESS", "BUILDING", "DEPLOYING").
    static func deploymentStatus(deploymentId: String) async throws -> String {
        let query = """
        query($id: String!) {
          deployment(id: $id) {
            status
          }
        }
        """
        let result = try await graphql(query, variables: ["id": deploymentId])

        guard let deployment = result["deployment"] as? [String: Any],
              let status = deployment["status"] as? String else {
            throw RailwayAPIError.invalidResponse("Cannot parse deployment status")
        }

        return status
    }

    /// Poll until deployment reaches SUCCESS (or fails/times out).
    static func pollDeployment(deploymentId: String, maxAttempts: Int = 30, interval: UInt64 = 3_000_000_000) async throws -> String {
        for attempt in 0..<maxAttempts {
            let status = try await deploymentStatus(deploymentId: deploymentId)
            let upper = status.uppercased()

            if upper == "SUCCESS" {
                return "SUCCESS"
            }
            if upper == "FAILED" || upper == "CRASHED" || upper == "REMOVED" {
                throw RailwayAPIError.deployFailed(status)
            }

            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: interval)
            }
        }

        return "TIMEOUT"
    }

    // MARK: - Private

    private static func requireAPIKey() throws -> String {
        guard let key = KeychainHelper.load(key: keychainKey), !key.isEmpty else {
            throw RailwayAPIError.missingAPIKey
        }
        return key
    }

    private static func graphql(_ query: String, variables: [String: Any]) async throws -> [String: Any] {
        let apiKey = try requireAPIKey()
        guard let url = URL(string: graphqlURL) else {
            throw RailwayAPIError.invalidResponse("Bad GraphQL URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["query": query, "variables": variables]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RailwayAPIError.invalidResponse("Cannot parse GraphQL response")
        }

        if let errors = json["errors"] as? [[String: Any]],
           let firstError = errors.first,
           let message = firstError["message"] as? String {
            throw RailwayAPIError.graphqlError(message)
        }

        guard let dataObj = json["data"] as? [String: Any] else {
            throw RailwayAPIError.invalidResponse("No 'data' in GraphQL response")
        }

        return dataObj
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw RailwayAPIError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Errors

enum RailwayAPIError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case graphqlError(String)
    case invalidResponse(String)
    case deployFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Railway API key not configured. Add it in Deploy settings."
        case .httpError(let code, let body):
            return "Railway API error \(code): \(body.prefix(200))"
        case .graphqlError(let message):
            return "Railway GraphQL error: \(message)"
        case .invalidResponse(let detail):
            return "Invalid Railway response: \(detail)"
        case .deployFailed(let status):
            return "Railway deploy failed: \(status)"
        }
    }
}
