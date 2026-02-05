import Foundation

extension LocalWorkspaceService {
    // MARK: - GitHub Search

    /// Search GitHub for template repos
    func searchGitHub(query: String, sort: String = "stars", perPage: Int = 5) async throws -> [GitHubRepo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.github.com/search/repositories?q=\(encoded)&sort=\(sort)&per_page=\(perPage)"
        guard let url = URL(string: urlString) else { throw WorkspaceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WorkspaceError.githubSearchFailed
        }

        let result = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)
        return result.items.map { item in
            GitHubRepo(
                fullName: item.full_name,
                description: item.description ?? "",
                stars: item.stargazers_count,
                url: item.html_url,
                cloneUrl: item.clone_url,
                updatedAt: item.updated_at,
                language: item.language ?? "Unknown",
                license: item.license?.spdx_id
            )
        }
    }

}

// MARK: - GitHub API Types (private)

private struct GitHubSearchResponse: Codable {
    let items: [GitHubRepoItem]
}

private struct GitHubRepoItem: Codable {
    let full_name: String
    let description: String?
    let stargazers_count: Int
    let html_url: String
    let clone_url: String
    let updated_at: String
    let language: String?
    let license: GitHubLicense?
}

private struct GitHubLicense: Codable {
    let spdx_id: String?
}
