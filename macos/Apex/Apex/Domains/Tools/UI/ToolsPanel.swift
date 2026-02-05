import SwiftUI

// MARK: - Tools Panel

/// Right-side tools panel — rendered inside .inspector() with automatic Liquid Glass
struct ToolsPanel: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    let selectedPageId: String?
    let onProjectCreated: (String) -> Void
    var onOpenFloatingChat: (() -> Void)? = nil

    @State private var toolsHeight: CGFloat = 400
    @State private var isDraggingDivider = false

    private let minToolsHeight: CGFloat = 200
    private let minChatHeight: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            let maxToolsHeight = geometry.size.height - minChatHeight - 80

            VStack(spacing: 0) {
                // Tools content (scrollable, fixed height)
                ScrollView {
                    VStack(spacing: 8) {
                        NewProjectCard(appState: appState, chatViewModel: chatViewModel, onProjectCreated: onProjectCreated)
                        BuildSiteCard(appState: appState, chatViewModel: chatViewModel)

                        Divider()
                            .padding(.vertical, 4)

                        SettingsToolCard(appState: appState)
                    }
                    .padding(12)
                }
                .frame(height: toolsHeight)

                // Resizable divider
                ToolsPanelDivider(isDragging: $isDraggingDivider)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingDivider = true
                                let newHeight = toolsHeight + value.translation.height
                                toolsHeight = min(max(newHeight, minToolsHeight), maxToolsHeight)
                            }
                            .onEnded { _ in
                                isDraggingDivider = false
                            }
                    )

                // Chat header
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Chat")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: { onOpenFloatingChat?() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in floating window")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider()

                // Chat section (takes remaining space)
                ChatTabContent(
                    appState: appState,
                    chatViewModel: chatViewModel
                )
            }
        }
        .navigationTitle("Tools")
    }
}

// MARK: - Tools Panel Divider

struct ToolsPanelDivider: View {
    @Binding var isDragging: Bool

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.orange : Color.secondary.opacity(0.3))
            .frame(height: isDragging ? 3 : 1)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
