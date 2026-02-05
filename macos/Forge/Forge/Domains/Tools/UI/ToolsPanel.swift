import SwiftUI

// MARK: - Tools Panel

/// Right-side tools panel for actions, settings, and chat
struct ToolsPanel: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    let selectedPageId: String?
    @Binding var isExpanded: Bool
    let onProjectCreated: (String) -> Void
    var onOpenFloatingChat: (() -> Void)? = nil

    @State private var toolsHeight: CGFloat = 400
    @State private var dragStartHeight: CGFloat = 400
    @State private var isDraggingDivider = false

    private let panelWidth: CGFloat = 300
    private let minToolsHeight: CGFloat = 200
    private let minChatHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedPanel
            } else {
                collapsedPanel
            }
        }
        .frame(width: isExpanded ? panelWidth : 44)
        .background(Theme.Colors.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var expandedPanel: some View {
        GeometryReader { geometry in
            let maxToolsHeight = geometry.size.height - minChatHeight - 80

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Tools")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false } }) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                // Tools content (scrollable, fixed height)
                ScrollView {
                    VStack(spacing: 8) {
                        // New Project - always at top
                        NewProjectCard(appState: appState, onProjectCreated: onProjectCreated)

                        // Build full site from existing page
                        BuildSiteCard(appState: appState, chatViewModel: chatViewModel)

                        Divider()
                            .padding(.vertical, 4)

                        // Settings
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
                                if !isDraggingDivider {
                                    isDraggingDivider = true
                                    dragStartHeight = toolsHeight
                                }
                                let newHeight = dragStartHeight + value.translation.height
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
    }

    private var collapsedPanel: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Divider()
                .frame(width: 20)

            // Collapsed tool icons
            VStack(spacing: 8) {
                // New project button - expands panel
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true } }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                // Build site button
                CollapsedToolButton(icon: "rectangle.stack", color: .purple) {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                }

                Divider()
                    .frame(width: 20)

                CollapsedToolButton(icon: "gearshape", color: .gray) {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                }

                Divider()
                    .frame(width: 20)

                // Chat button
                CollapsedToolButton(icon: "bubble.left.and.bubble.right", color: .blue) {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                }
            }

            Spacer()
        }
    }

}

// MARK: - Tools Panel Divider

struct ToolsPanelDivider: View {
    @Binding var isDragging: Bool

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.blue : Color.secondary.opacity(0.3))
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
