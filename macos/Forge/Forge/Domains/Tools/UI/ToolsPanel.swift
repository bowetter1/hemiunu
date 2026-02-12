import SwiftUI

// MARK: - Tools Panel

/// Right-side tools panel for actions, settings, and chat
struct ToolsPanel: View {
    private enum ToolsFeedTab: String, CaseIterable {
        case activity
        case checklist
    }

    var appState: AppState
    var chatViewModel: ChatViewModel
    let selectedPageId: String?
    @Binding var isExpanded: Bool
    var onOpenFloatingChat: (() -> Void)? = nil

    @State private var toolsHeight: CGFloat = 320
    @State private var isDraggingDivider = false
    @State private var selectedToolsTab: ToolsFeedTab = .activity

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
                    HStack(spacing: 2) {
                        toolsTabButton(.activity, icon: "list.bullet.rectangle", title: "Activity")
                        toolsTabButton(.checklist, icon: "checklist", title: "Checklist")
                    }
                    .padding(2)
                    .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 7))

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
                        if selectedToolsTab == .activity {
                            if chatViewModel.activityLog.isActive {
                                ActivityLogView(log: chatViewModel.activityLog)
                            } else {
                                emptyToolsState(icon: "list.bullet.rectangle", title: "No activity yet")
                            }
                        } else {
                            if chatViewModel.checklist.isActive {
                                ChecklistView(checklist: chatViewModel.checklist)
                            } else {
                                emptyToolsState(icon: "checklist", title: "No checklist yet")
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    Spacer()
                    HStack(spacing: 2) {
                        chatActionButton(
                            icon: "folder.badge.plus",
                            title: "New Project",
                            isEnabled: !chatViewModel.isStreaming,
                            action: { startNewChat() }
                        )
                        .help("New project")

                        chatActionButton(
                            icon: "arrow.up.right.square",
                            title: "Pop Out",
                            action: { onOpenFloatingChat?() }
                        )
                        .help("Open separate chat window")
                    }
                    .padding(2)
                    .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 7))
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

    private func startNewChat() {
        chatViewModel.startNewChat()
        appState.clearCurrentProject()
        appState.currentMode = .design
    }

    private func toolsTabButton(_ tab: ToolsFeedTab, icon: String, title: String) -> some View {
        let isSelected = selectedToolsTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedToolsTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .fontDesign(.rounded)
            }
            .foregroundStyle(isSelected ? .blue : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func chatActionButton(
        icon: String,
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .fontDesign(.rounded)
            }
            .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.45))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func emptyToolsState(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
