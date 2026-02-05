import Foundation

extension BossService {
    // MARK: - API Keys

    static func readAPIKeys() -> [String: String] {
        let keyFiles: [(envName: String, fileName: String)] = [
            ("ANTHROPIC_API_KEY", "anthropic_key"),
            ("DAYTONA_API_KEY", "daytona_key"),
            ("PEXELS_API_KEY", "pexels_key"),
            ("OPENAI_API_KEY", "openai_key"),
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var result: [String: String] = [:]

        for (envName, fileName) in keyFiles {
            if let value = ProcessInfo.processInfo.environment[envName], !value.isEmpty {
                result[envName] = value
                continue
            }
            let path = "\(home)/.apex/\(fileName)"
            if let value = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                result[envName] = value
            }
        }
        return result
    }

}
