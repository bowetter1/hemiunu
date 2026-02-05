import SwiftUI

/// Main Code Mode view with file tree, editor, and preview
struct CodeModeView: View {
    @ObservedObject var appState: AppState
    @Binding var selectedPageId: String?
    @StateObject private var viewModel: CodeViewModel
    @State private var previewRefreshToken = UUID()

    private let fileTreeWidth: CGFloat = 240

    init(appState: AppState, selectedPageId: Binding<String?>) {
        self.appState = appState
        _selectedPageId = selectedPageId
        _viewModel = StateObject(wrappedValue: CodeViewModel(appState: appState))
    }

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
            viewModel.loadFiles()
        }
        .onChange(of: appState.currentProject?.id) { _, _ in
            viewModel.loadFiles()
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
                Button(action: viewModel.loadFiles) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingFiles)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // File tree
            if viewModel.isLoadingFiles {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
            } else {
                FileTreeView(
                    files: viewModel.files,
                    selectedPath: $viewModel.selectedFilePath,
                    onFileSelect: viewModel.loadFileContent
                )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(spacing: 0) {
            if let path = viewModel.selectedFilePath {
                CodeEditorView(
                    content: $viewModel.currentFileContent,
                    fileName: (path as NSString).lastPathComponent,
                    language: detectLanguage(path),
                    isLoading: viewModel.isLoadingContent,
                    onSave: viewModel.saveCurrentFile,
                    onClose: {
                        viewModel.selectedFilePath = nil
                        viewModel.currentFileContent = ""
                    }
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
                Button(action: {
                    if let path = viewModel.selectedFilePath {
                        viewModel.loadFileContent(path)
                        previewRefreshToken = UUID()
                    }
                }) {
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
                WebPreview(
                    html: viewModel.currentFileContent,
                    sidebarVisible: false,
                    toolsPanelVisible: false,
                    selectedDevice: .desktop
                )
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
        guard let path = viewModel.selectedFilePath else { return false }
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
}
