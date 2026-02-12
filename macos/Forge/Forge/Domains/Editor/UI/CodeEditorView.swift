import SwiftUI

/// Main code editor with syntax highlighting
struct CodeEditorView: View {
    @Binding var content: String
    let fileName: String
    let language: String
    let isLoading: Bool
    let onSave: () -> Void

    @State private var lineCount = 1
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if isLoading {
                loadingView
            } else {
                editorArea
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: iconForFile)
                    .font(.system(size: 11))
                    .foregroundStyle(colorForFile)

                Text(fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2),
                alignment: .bottom
            )

            Spacer()

            Button(action: onSave) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10))
                    Text("Save")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var editorArea: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                lineNumbers
                    .frame(width: 50)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)

                ScrollView([.horizontal, .vertical]) {
                    TextEditor(text: $content)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .frame(minWidth: geometry.size.width - 51, minHeight: geometry.size.height)
                }
            }
        }
    }

    private var lineNumbers: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(lineCount, 1), id: \.self) { line in
                    Text("\(line)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(height: 18)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onChange(of: content) { _, newValue in
            lineCount = newValue.components(separatedBy: "\n").count
        }
        .onAppear {
            lineCount = content.components(separatedBy: "\n").count
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Text("Loading file...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconForFile: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "text.badge.star"
        case "js", "jsx": return "j.square"
        case "ts", "tsx": return "t.square"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        case "swift": return "swift"
        default: return "doc"
        }
    }

    private var colorForFile: Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return .yellow
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "html": return .orange
        case "css", "scss": return .purple
        case "json": return .green
        case "swift": return .orange
        default: return .secondary
        }
    }
}
