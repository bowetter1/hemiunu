import Foundation

extension LocalWorkspaceService {
    // MARK: - Workspace Cleanup

    /// Remove old workspace directories older than the given interval
    func cleanOldWorkspaces(olderThan interval: TimeInterval = 7 * 24 * 3600) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-interval)
        for url in contents {
            let name = url.lastPathComponent
            guard (name.hasPrefix("session-") || name.hasPrefix("boss-") || name.hasPrefix("solo-")),
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }

            // Only remove if the directory is empty or has no meaningful files
            let files = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            let meaningfulFiles = files.filter { !$0.hasPrefix(".") }
            if meaningfulFiles.isEmpty {
                try? fm.removeItem(at: url)
            }
        }
    }

}
