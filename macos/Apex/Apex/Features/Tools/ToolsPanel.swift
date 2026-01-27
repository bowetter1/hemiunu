import SwiftUI

// MARK: - Tools Panel

/// Right-side tools panel for actions, settings, and chat
struct ToolsPanel: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    let selectedPageId: String?  // Currently selected page (used as parent for generate site)
    @Binding var isExpanded: Bool
    let onProjectCreated: (String) -> Void
    var onOpenFloatingChat: (() -> Void)? = nil

    @State private var isGenerating = false
    @State private var generationResult: GenerateSiteResponse?
    @State private var errorMessage: String?
    @State private var toolsHeight: CGFloat = 400
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
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
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
                        NewProjectCard(client: client, onProjectCreated: onProjectCreated)

                        Divider()
                            .padding(.vertical, 4)

                        // Generate Site
                        if isGenerating {
                            GeneratingCard()
                        } else if let result = generationResult {
                            GenerationResultCard(result: result) {
                                generationResult = nil
                            }
                        } else {
                            ToolCard(
                                icon: "globe",
                                title: "Generate Site",
                                description: "Create full website from layout",
                                color: .blue,
                                disabled: client.currentProject == nil || client.pages.isEmpty
                            ) {
                                generateSite()
                            }
                        }

                        if let error = errorMessage {
                            ErrorCard(message: error) {
                                errorMessage = nil
                            }
                        }

                        // Design
                        DesignToolCard()

                        // Deploy
                        DeployToolCard()

                        // Git
                        GitToolCard()

                        // Database
                        DatabaseToolCard()

                        // Settings
                        SettingsToolCard()
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
                    client: client,
                    webSocket: webSocket,
                    selectedPageId: selectedPageId,
                    onProjectCreated: { projectId in
                        onProjectCreated(projectId)
                    }
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
                                    colors: [.orange, .orange],
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

                Divider()
                    .frame(width: 20)

                CollapsedToolButton(icon: "globe", color: .blue)
                CollapsedToolButton(icon: "paintbrush", color: .purple)
                CollapsedToolButton(icon: "paperplane", color: .green)
                CollapsedToolButton(icon: "arrow.triangle.branch", color: .orange)
                CollapsedToolButton(icon: "cylinder", color: .cyan)
                CollapsedToolButton(icon: "gearshape", color: .gray)

                Divider()
                    .frame(width: 20)

                // Chat button
                CollapsedToolButton(icon: "bubble.left.and.bubble.right", color: .blue)
            }

            Spacer()
        }
    }

    private func generateSite() {
        guard let projectId = client.currentProject?.id else { return }

        guard let pageId = selectedPageId else {
            errorMessage = "Select a layout page first"
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let result = try await client.generateSite(projectId: projectId, parentPageId: pageId)

                // Refresh pages to show new ones
                let updatedPages = try await client.getPages(projectId: projectId)

                await MainActor.run {
                    isGenerating = false
                    generationResult = result
                    client.pages = updatedPages
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
