import SwiftUI

// MARK: - Tools Panel

/// Right-side tools panel for actions, settings, and chat
struct ToolsPanel: View {
    var appState: AppState
    var chatViewModel: ChatViewModel
    let selectedPageId: String?
    @Binding var isExpanded: Bool
    var onOpenFloatingChat: (() -> Void)? = nil

    @State private var toolsHeight: CGFloat = 320
    @State private var isDraggingDivider = false

    private let panelWidth: CGFloat = 300
    private let minToolsHeight: CGFloat = 180
    private let minChatHeight: CGFloat = 150

    var body: some View {
        expandedPanel
            .frame(width: panelWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: 12, style: .continuous))
    }

    private var expandedPanel: some View {
        GeometryReader { geometry in
            let maxToolsHeight = geometry.size.height - minChatHeight - 80

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Activity")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false } }) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().opacity(0.5)

                // Tools content (scrollable, fixed height)
                ScrollView {
                    VStack(spacing: 8) {
                        // Boss checklist progress
                        ChecklistView(checklist: chatViewModel.checklist)

                        // Boss activity log
                        ActivityLogView(log: chatViewModel.activityLog)
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
                        .foregroundStyle(.secondary)
                    Text("Chat")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: { onOpenFloatingChat?() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in floating window")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider().opacity(0.5)

                // Chat section (takes remaining space)
                ChatTabContent(
                    appState: appState,
                    chatViewModel: chatViewModel
                )
            }
        }
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
