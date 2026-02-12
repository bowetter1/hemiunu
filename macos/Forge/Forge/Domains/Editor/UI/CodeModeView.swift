import Foundation
import SwiftUI

/// Code Mode command center with file tree, editor, insights, and context dock
struct CodeModeView: View {
    var appState: AppState
    @Binding var selectedPageId: String?
    @State var viewModel: CodeViewModel
    @State var commandQuery: String = ""

    private let fileTreeWidth: CGFloat = 250

    init(appState: AppState, selectedPageId: Binding<String?>) {
        self.appState = appState
        _selectedPageId = selectedPageId
        _viewModel = State(wrappedValue: CodeViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()

            HSplitView {
                fileTreeSection
                    .frame(minWidth: 200, idealWidth: fileTreeWidth, maxWidth: 320)

                editorSection
                    .frame(minWidth: 420)

                insightsSection
                    .frame(minWidth: 290, idealWidth: 330, maxWidth: 420)
            }

            Divider()
            contextDock
                .frame(height: 96)
        }
        .onAppear {
            viewModel.loadFiles()
        }
        .onChange(of: appState.currentProject?.id) { _, _ in
            viewModel.loadFiles()
        }
    }

    // MARK: - Command Bar

    private var commandBar: some View {
        HStack(spacing: 10) {
            Text("CODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            Text(projectDisplayName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search symbol/file...", text: $commandQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))

            commandButton(title: "Explain", icon: "text.bubble", action: runExplain)
            commandButton(title: "Refactor", icon: "wand.and.stars", action: runRefactor)
            commandButton(title: "Domain Scan", icon: "brain.head.profile", action: runDeepScan)
            commandButton(title: "Run Tests", icon: "checkmark.circle", action: runTests)
            commandButton(title: "Commit", icon: "arrow.triangle.branch", action: commitChanges)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - File Tree Section

    private var fileTreeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(viewModel.files.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: viewModel.loadFiles) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingFiles)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if viewModel.isLoadingFiles {
                VStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
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
                    onSave: viewModel.saveCurrentFile
                )
            } else {
                emptyEditorState
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyEditorState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Select a file to edit")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Helpers

    private var projectDisplayName: String {
        appState.currentProject?.brief ?? "No Project"
    }

    private func commandButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
