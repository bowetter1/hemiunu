import SwiftUI

/// Main code editor with syntax highlighting
struct CodeEditorView: View {
    @Binding var content: String
    let fileName: String
    let language: String
    let isLoading: Bool
    let onSave: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var lineCount = 1
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            // Editor area
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
            // File tab
            HStack(spacing: 6) {
                Image(systemName: iconForFile)
                    .font(.system(size: 11))
                    .foregroundColor(colorForFile)

                Text(fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                // Close button
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.accentColor),
                alignment: .bottom
            )

            Spacer()

            // Save button
            Button(action: onSave) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10))
                    Text("Save")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var editorArea: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...max(lineCount, 1), id: \.self) { line in
                            Text("\(line)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(height: 18)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .frame(width: 50)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    // Divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)

                    // Code content
                    TextEditor(text: $content)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .focused($isFocused)
                        .frame(minWidth: geometry.size.width - 51, minHeight: max(CGFloat(lineCount) * 18 + 16, geometry.size.height))
                }
            }
        }
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
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading file...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconForFile: String {
        FileTypeAppearance.icon(forPath: fileName)
    }

    private var colorForFile: Color {
        FileTypeAppearance.color(forPath: fileName)
    }
}
