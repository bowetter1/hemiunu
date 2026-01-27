import SwiftUI

// MARK: - Floating Chat Bar

struct FloatingChatWindow: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    var selectedPageId: String?
    var onProjectCreated: ((String) -> Void)?
    let onClose: () -> Void

    @State private var inputText = ""
    @State private var isSending = false
    @State private var position: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var hasInitialPosition = false

    var body: some View {
        GeometryReader { geometry in
            let initialPosition = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height - 50
            )

            HStack(spacing: 0) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(isDragging ? .orange : .secondary.opacity(0.5))
                    .frame(width: 30, height: 44)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Input field
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    TextField("Ask anything...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit { sendMessage() }

                    if isSending {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(inputText.isEmpty ? .secondary.opacity(0.5) : .orange)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 44)
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isDragging ? Color.orange : Color.secondary.opacity(0.2), lineWidth: isDragging ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            .frame(maxWidth: 600)
            .position(
                x: (hasInitialPosition ? position.x : initialPosition.x) + dragOffset.width,
                y: (hasInitialPosition ? position.y : initialPosition.y) + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        let currentPos = hasInitialPosition ? position : initialPosition
                        position = CGPoint(
                            x: currentPos.x + value.translation.width,
                            y: currentPos.y + value.translation.height
                        )
                        dragOffset = .zero
                        hasInitialPosition = true
                    }
            )
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true

        let text = inputText
        inputText = ""

        Task {
            do {
                if client.currentProject == nil {
                    // Create new project
                    let project = try await client.createProject(brief: text)
                    await MainActor.run {
                        isSending = false
                        onProjectCreated?(project.id)
                    }
                } else if let project = client.currentProject, let pageId = selectedPageId {
                    // Edit existing page
                    try await client.editPage(projectId: project.id, pageId: pageId, instruction: text)
                    await MainActor.run {
                        isSending = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                }
                // Error handled silently
            }
        }
    }
}
