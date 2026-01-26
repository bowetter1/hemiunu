import SwiftUI

/// Main Code Mode view with file tree, editor, and preview
struct CodeModeView: View {
    @ObservedObject var client: APIClient
    @Binding var selectedPageId: String?

    @State private var files: [FileTreeNode] = []
    @State private var selectedFilePath: String?
    @State private var currentFileContent: String = ""
    @State private var isLoadingFiles = false
    @State private var isLoadingContent = false
    @State private var isSaving = false
    @State private var showGenerateSheet = false
    @State private var isGenerating = false
    @State private var generationProgress: String = ""
    @State private var errorMessage: String?

    private let fileTreeWidth: CGFloat = 240

    var body: some View {
        HSplitView {
            // Left: File tree
            fileTreeSection
                .frame(minWidth: 200, idealWidth: fileTreeWidth, maxWidth: 300)

            // Center: Code editor
            editorSection
                .frame(minWidth: 300)

            // Right: Preview
            previewSection
                .frame(minWidth: 300)
        }
        .onAppear {
            loadFiles()
        }
        .onChange(of: client.currentProject?.id) { _, _ in
            loadFiles()
        }
        .sheet(isPresented: $showGenerateSheet) {
            GenerateProjectSheet(
                isPresented: $showGenerateSheet,
                isGenerating: $isGenerating,
                progress: $generationProgress,
                onGenerate: generateProject
            )
        }
    }

    // MARK: - File Tree Section

    private var fileTreeSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                // Refresh button
                Button(action: loadFiles) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingFiles)

                // Generate button
                Button(action: { showGenerateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // File tree
            if isLoadingFiles {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
            } else {
                FileTreeView(
                    files: files,
                    selectedPath: $selectedFilePath,
                    onFileSelect: loadFileContent
                )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(spacing: 0) {
            if let path = selectedFilePath {
                CodeEditorView(
                    content: $currentFileContent,
                    fileName: (path as NSString).lastPathComponent,
                    language: detectLanguage(path),
                    isLoading: isLoadingContent,
                    onSave: saveCurrentFile
                )
            } else {
                emptyEditorState
            }
        }
    }

    private var emptyEditorState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text("Select a file to edit")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            if files.isEmpty && client.currentProject != nil {
                Button(action: { showGenerateSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate Project")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Preview content
            if isHtmlFile {
                HTMLWebView(html: currentFileContent, projectId: client.currentProject?.id)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "eye.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Preview not available")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Select an HTML file to preview")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var isHtmlFile: Bool {
        guard let path = selectedFilePath else { return false }
        return path.lowercased().hasSuffix(".html")
    }

    private func detectLanguage(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "python"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "jsx": return "javascriptreact"
        case "tsx": return "typescriptreact"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "md": return "markdown"
        case "swift": return "swift"
        default: return "text"
        }
    }

    // MARK: - API Calls

    private func loadFiles() {
        guard let projectId = client.currentProject?.id else { return }

        isLoadingFiles = true

        Task {
            do {
                let response = try await client.listProjectFiles(projectId: projectId)
                await MainActor.run {
                    files = response.tree.map { $0.toNode() }
                    isLoadingFiles = false
                }
            } catch {
                await MainActor.run {
                    isLoadingFiles = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadFileContent(_ path: String) {
        guard let projectId = client.currentProject?.id else { return }

        isLoadingContent = true

        Task {
            do {
                let file = try await client.readProjectFile(projectId: projectId, path: path)
                await MainActor.run {
                    currentFileContent = file.content ?? ""
                    isLoadingContent = false
                }
            } catch {
                await MainActor.run {
                    isLoadingContent = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveCurrentFile() {
        guard let projectId = client.currentProject?.id,
              let path = selectedFilePath else { return }

        isSaving = true

        Task {
            do {
                _ = try await client.writeProjectFile(
                    projectId: projectId,
                    path: path,
                    content: currentFileContent
                )
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func generateProject(type: String) {
        guard let projectId = client.currentProject?.id else { return }

        isGenerating = true
        generationProgress = "Starting generation..."

        Task {
            do {
                let result = try await client.generateCodeProject(
                    projectId: projectId,
                    projectType: type
                )
                await MainActor.run {
                    isGenerating = false
                    showGenerateSheet = false
                    loadFiles()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Generate Project Sheet

struct GenerateProjectSheet: View {
    @Binding var isPresented: Bool
    @Binding var isGenerating: Bool
    @Binding var progress: String

    let onGenerate: (String) -> Void

    @State private var selectedType = "python"

    let projectTypes = [
        ("python", "Python", "Basic Python project"),
        ("flask", "Flask", "Flask web application"),
        ("fastapi", "FastAPI", "FastAPI REST API"),
        ("node", "Node.js", "Node.js project"),
        ("react", "React", "React frontend app"),
        ("nextjs", "Next.js", "Next.js fullstack app"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generate Project")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding()

            Divider()

            if isGenerating {
                generatingView
            } else {
                projectTypeSelector
            }
        }
        .frame(width: 400, height: 350)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var projectTypeSelector: some View {
        VStack(spacing: 16) {
            Text("Choose a project type:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(projectTypes, id: \.0) { type, name, description in
                        ProjectTypeRow(
                            type: type,
                            name: name,
                            description: description,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Generate button
            Button(action: { onGenerate(selectedType) }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate \(projectTypes.first { $0.0 == selectedType }?.1 ?? "") Project")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text("Generating project...")
                .font(.system(size: 14, weight: .medium))

            Text(progress)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProjectTypeRow: View {
    let type: String
    let name: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: iconFor(type))
                    .font(.system(size: 20))
                    .foregroundColor(colorFor(type))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconFor(_ type: String) -> String {
        switch type {
        case "python", "flask", "fastapi": return "text.badge.star"
        case "node": return "server.rack"
        case "react", "nextjs": return "atom"
        default: return "doc"
        }
    }

    private func colorFor(_ type: String) -> Color {
        switch type {
        case "python", "flask", "fastapi": return .yellow
        case "node": return .green
        case "react", "nextjs": return .cyan
        default: return .secondary
        }
    }
}

#Preview {
    CodeModeView(
        client: APIClient(),
        selectedPageId: .constant(nil)
    )
    .frame(width: 1200, height: 700)
}
