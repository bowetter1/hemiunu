import SwiftUI
import Combine

/// CodeViewModel — owns file tree state and code editing logic
@MainActor
class CodeViewModel: ObservableObject {
    @Published var files: [FileTreeNode] = []
    @Published var selectedFilePath: String?
    @Published var currentFileContent: String = ""
    @Published var isLoadingFiles = false
    @Published var isLoadingContent = false
    @Published var isSaving = false
    @Published var isGenerating = false
    @Published var generationProgress: String = ""
    @Published var errorMessage: String?

    private let appState: AppState
    private var client: APIClient { appState.client }

    init(appState: AppState) {
        self.appState = appState
    }

    var currentProjectId: String? {
        appState.currentProject?.id
    }

    // MARK: - File Operations

    func loadFiles() {
        guard let projectId = currentProjectId else { return }
        isLoadingFiles = true

        Task {
            do {
                let response = try await client.fileService.list(projectId: projectId)
                files = response.tree.map { $0.toNode() }
                isLoadingFiles = false
            } catch {
                isLoadingFiles = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadFileContent(_ path: String) {
        guard let projectId = currentProjectId else { return }
        isLoadingContent = true

        Task {
            do {
                let file = try await client.fileService.read(projectId: projectId, path: path)
                currentFileContent = file.content ?? ""
                isLoadingContent = false
            } catch {
                isLoadingContent = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveCurrentFile() {
        guard let projectId = currentProjectId,
              let path = selectedFilePath else { return }
        isSaving = true

        Task {
            do {
                _ = try await client.fileService.write(
                    projectId: projectId,
                    path: path,
                    content: currentFileContent
                )
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func generateProject(type: String) {
        guard let projectId = currentProjectId else { return }
        isGenerating = true
        generationProgress = "Starting generation..."

        Task {
            do {
                _ = try await client.codeGen.generate(
                    projectId: projectId,
                    projectType: type
                )
                isGenerating = false
                loadFiles()
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
