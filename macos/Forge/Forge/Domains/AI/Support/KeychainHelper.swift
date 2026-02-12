import Foundation
import Security

/// Save and load API keys securely in macOS Keychain
enum KeychainHelper {

    /// Save a string value to the Keychain
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bowetter.Forge",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bowetter.Forge",
            kSecValueData as String: data,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Load a string value — checks ~/Forge/.env first, then Keychain
    static func load(key: String) -> String? {
        // Check .env file first (fast, no Keychain prompt)
        if let envValue = loadFromEnv(key: key) {
            return envValue
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bowetter.Forge",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Read key from ~/Forge/.env (format: KEY=value per line)
    private static func loadFromEnv(key: String) -> String? {
        let envURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Forge/.env")
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2, String(parts[0]) == key {
                return String(parts[1])
            }
        }
        return nil
    }

    /// Delete a value from the Keychain
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bowetter.Forge",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
