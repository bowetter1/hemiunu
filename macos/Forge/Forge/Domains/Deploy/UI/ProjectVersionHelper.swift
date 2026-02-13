import SwiftUI

/// Shared version-resolution logic used by all deploy popovers.
@MainActor
struct ProjectVersionHelper {
    let appState: AppState
    let selectedVersion: String

    /// Available version directories for current project
    var versions: [String] {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return ["v1"] }
        let projectName = String(selectedId.dropFirst(6))
        let parts = projectName.components(separatedBy: "/")
        if parts.count == 2 {
            let parent = parts[0]
            return appState.localProjects
                .filter { $0.name.hasPrefix("\(parent)/v") }
                .map { $0.name.components(separatedBy: "/").last ?? $0.name }
                .sorted()
        }
        return ["v1"]
    }

    /// Current project's version label
    var currentVersion: String {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return "v1" }
        let name = String(selectedId.dropFirst(6))
        let parts = name.components(separatedBy: "/")
        return parts.count == 2 ? parts[1] : "v1"
    }

    /// Full project name for current selection (e.g. "coffee-shop/v1")
    var currentProjectName: String {
        guard let selectedId = appState.selectedProjectId,
              selectedId.hasPrefix("local:") else { return "" }
        return String(selectedId.dropFirst(6))
    }

    /// Parent project name (e.g. "coffee-shop" from "coffee-shop/v1")
    var parentProjectName: String {
        let name = currentProjectName
        return name.components(separatedBy: "/").first ?? name
    }

    /// Project name for selected version (e.g. "coffee-shop/v2")
    var selectedProjectName: String {
        guard !parentProjectName.isEmpty else { return "" }
        return "\(parentProjectName)/\(selectedVersion)"
    }

    /// Builder name for the selected version
    var selectedBuilderName: String? {
        builderName(for: selectedVersion)
    }

    /// Read agent-name.txt for a version to get the builder name
    func builderName(for version: String) -> String? {
        let project = "\(parentProjectName)/\(version)"
        return try? appState.workspace.readFile(project: project, path: "agent-name.txt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
