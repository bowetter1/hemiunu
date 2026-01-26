import SwiftUI
import UniformTypeIdentifiers

/// Main app router - handles navigation between modes
struct AppRouter: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var client: APIClient
    @State private var showToolsPanel = true

    init() {
        _client = ObservedObject(wrappedValue: AppState.shared.client)
    }

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            GridBackground()

            // Main layout - ignore safe area to flow into title bar
            VStack(spacing: 0) {
                // Topbar spanning full width - flows into title bar area
                Topbar(
                    showSidebar: $appState.showSidebar,
                    selectedMode: $appState.currentMode,
                    appearanceMode: $appState.appearanceMode,
                    isConnected: appState.isConnected,
                    errorMessage: appState.errorMessage,
                    hasProject: client.currentProject != nil,
                    logs: client.projectLogs,
                    onNewProject: {
                        appState.clearCurrentProject()
                        appState.currentMode = .design
                    },
                    showModeSelector: false,
                    inlineTrafficLights: true
                )
                .padding(.horizontal, 0)

                // Content row: left sidebar + main + right sidebar
                HStack(spacing: 0) {
                    // Left sidebar
                    if appState.showSidebar {
                        UnifiedSidebar(
                            client: client,
                            webSocket: appState.wsClient,
                            currentMode: appState.currentMode,
                            selectedProjectId: $appState.selectedProjectId,
                            selectedVariantId: $appState.selectedVariantId,
                            selectedPageId: $appState.selectedPageId,
                            onNewProject: {
                                appState.clearCurrentProject()
                                appState.currentMode = .design
                            },
                            onClose: {
                                appState.showSidebar = false
                            }
                        )
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                    }

                    // Main content card
                    modeContent
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.leading, appState.showSidebar ? 0 : 16)
                        .padding(.trailing, 8)

                    // Right tools panel
                    ToolsPanel(
                        client: client,
                        webSocket: appState.wsClient,
                        selectedPageId: appState.selectedPageId,
                        isExpanded: $showToolsPanel,
                        onProjectCreated: { projectId in
                            appState.selectedProjectId = projectId
                            appState.currentMode = .design
                        },
                        onOpenFloatingChat: {
                            appState.showFloatingChat = true
                        }
                    )
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(edges: .top)

            // Centered Mode Selector overlay (centered on entire window)
            VStack {
                ModeSelector(selectedMode: $appState.currentMode)
                    .padding(.top, 8)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(20)

            // Floating chat window
            if appState.showFloatingChat {
                FloatingChatWindow(
                    client: client,
                    webSocket: appState.wsClient,
                    selectedPageId: appState.selectedPageId,
                    onProjectCreated: { projectId in
                        appState.selectedProjectId = projectId
                        appState.currentMode = .design
                    },
                    onClose: {
                        appState.showFloatingChat = false
                    }
                )
                .zIndex(30)
            }
        }
        .onAppear {
            Task {
                await appState.connect()
            }
        }
        .onChange(of: appState.selectedProjectId) { _, newId in
            if let id = newId {
                Task {
                    await appState.loadProject(id: id)
                }
            }
        }
        .onChange(of: appState.wsClient.lastEvent) { _, newEvent in
            handleWebSocketEvent(newEvent)
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appState.currentMode {
        case .design:
            DesignView(
                client: client,
                wsClient: appState.wsClient,
                sidebarVisible: appState.showSidebar,
                toolsPanelVisible: showToolsPanel,
                selectedPageId: appState.selectedPageId,
                onProjectCreated: { projectId in
                    Task {
                        await appState.loadProject(id: projectId)
                    }
                }
            )
        case .code:
            CodeModeView(client: client, selectedPageId: $appState.selectedPageId)
        }
    }

    // MARK: - WebSocket

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event,
              let projectId = client.currentProject?.id else { return }

        switch event {
        case .moodboardReady, .layoutsReady, .statusChanged, .pageUpdated:
            appState.scheduleLoadProject(id: projectId)
        case .clarificationNeeded:
            // Also reload project to update status
            appState.scheduleLoadProject(id: projectId)
        case .error(let message):
            appState.errorMessage = message
        default:
            break
        }
    }
}

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
                CollapsedToolButton(icon: "rocket", color: .green)
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

// MARK: - New Project Card

struct NewProjectCard: View {
    @ObservedObject var client: APIClient
    let onProjectCreated: (String) -> Void

    @State private var isExpanded = false
    @State private var briefText = ""
    @State private var websiteURL = ""
    @State private var selectedImage: NSImage?
    @State private var isCreating = false
    @State private var isDraggingOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)

                    Text("New Project")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("What do you want to build?", text: $briefText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .lineLimit(3...5)
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                    }

                    // URL
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Reference URL", systemImage: "link")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("https://example.com", text: $websiteURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Image upload
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Inspiration", systemImage: "photo")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        ZStack {
                            if let image = selectedImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button(action: { selectedImage = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: isDraggingOver ? "arrow.down.circle.fill" : "photo.badge.plus")
                                        .font(.system(size: 20))
                                        .foregroundColor(isDraggingOver ? .blue : .secondary.opacity(0.5))
                                    Text("Drop image or click")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isDraggingOver ? Color.blue : Color.secondary.opacity(0.2),
                                            style: StrokeStyle(lineWidth: 1, dash: [4])
                                        )
                                )
                                .cornerRadius(8)
                                .onTapGesture { openImagePicker() }
                            }
                        }
                        .onDrop(of: [.image, .fileURL], isTargeted: $isDraggingOver) { providers in
                            handleImageDrop(providers)
                        }
                    }

                    // Create button
                    Button(action: createProject) {
                        HStack(spacing: 6) {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                            }
                            Text(isCreating ? "Creating..." : "Create")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            canCreate
                                ? LinearGradient(colors: [.orange, .orange], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate || isCreating)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var canCreate: Bool {
        !briefText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .png, .jpeg]

        if panel.runModal() == .OK, let url = panel.url {
            selectedImage = NSImage(contentsOf: url)
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    DispatchQueue.main.async {
                        selectedImage = image as? NSImage
                    }
                }
                return true
            }
        }
        return false
    }

    private func createProject() {
        guard canCreate else { return }
        isCreating = true

        var enhancedBrief = briefText

        if !websiteURL.isEmpty {
            enhancedBrief += "\n\nReference website: \(websiteURL)"
        }

        if selectedImage != nil {
            enhancedBrief += "\n\n(User provided an inspiration image)"
        }

        Task {
            do {
                let project = try await client.createProject(brief: enhancedBrief)
                await MainActor.run {
                    isCreating = false
                    isExpanded = false
                    briefText = ""
                    websiteURL = ""
                    selectedImage = nil
                    onProjectCreated(project.id)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // Project creation failed
                }
            }
        }
    }
}

// MARK: - Generation Cards

struct GeneratingCard: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(6)

            Text("Generating\(String(repeating: ".", count: dotCount))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

struct GenerationResultCard: View {
    let result: GenerateSiteResponse
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .frame(width: 28, height: 28)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)

                Text("Generated!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)

            // List created pages
            VStack(alignment: .leading, spacing: 4) {
                ForEach(result.pagesCreated, id: \.self) { page in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(page)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(.red)
                .frame(width: 28, height: 28)
                .background(Color.red.opacity(0.15))
                .cornerRadius(6)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(disabled ? .secondary : color)
                    .frame(width: 28, height: 28)
                    .background((disabled ? Color.secondary : color).opacity(0.15))
                    .cornerRadius(6)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .background(isHovering && !disabled ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .opacity(disabled ? 0.5 : 1)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct CollapsedToolButton: View {
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Design Tool Card

struct DesignToolCard: View {
    @State private var isExpanded = false
    @State private var selectedViewport: String = "desktop"
    @State private var zoomLevel: Double = 100

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .frame(width: 28, height: 28)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)

                    Text("Design")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Viewport selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Viewport")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            ViewportButton(icon: "desktopcomputer", label: "Desktop", isSelected: selectedViewport == "desktop") {
                                selectedViewport = "desktop"
                            }
                            ViewportButton(icon: "tablet", label: "Tablet", isSelected: selectedViewport == "tablet") {
                                selectedViewport = "tablet"
                            }
                            ViewportButton(icon: "iphone", label: "Mobile", isSelected: selectedViewport == "mobile") {
                                selectedViewport = "mobile"
                            }
                        }
                    }

                    // Zoom
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zoom")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: { zoomLevel = max(50, zoomLevel - 10) }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Text("\(Int(zoomLevel))%")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .frame(width: 40)

                            Button(action: { zoomLevel = min(200, zoomLevel + 10) }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    // Brand Colors (mockup)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brand Colors")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ColorSwatch(color: .orange)
                            ColorSwatch(color: .black)
                            ColorSwatch(color: Color(white: 0.95))
                            ColorSwatch(color: .blue)
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Typography (mockup)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Typography")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Heading:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Inter Bold")
                                .font(.system(size: 10, weight: .medium))
                        }
                        HStack {
                            Text("Body:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Inter Regular")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ViewportButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 8))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple : Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ColorSwatch: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Deploy Tool Card

struct DeployToolCard: View {
    @State private var isExpanded = false
    @State private var autoDeploy = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "rocket")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .frame(width: 28, height: 28)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)

                    Text("Deploy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Current deployment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Production")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("apex-demo.vercel.app")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }

                        Text("Updated 2h ago")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Deploy Now")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Auto-deploy toggle
                    Toggle(isOn: $autoDeploy) {
                        Text("Auto-deploy on push")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Git Tool Card

struct GitToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)

                    Text("Git")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Changes badge
                    Text("3")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(8)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Branch selector
                    HStack {
                        Text("Branch:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text("main")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // Changes list
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uncommitted changes")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        FileChangeRow(filename: "index.html", status: "M")
                        FileChangeRow(filename: "about.html", status: "M")
                        FileChangeRow(filename: "styles.css", status: "A")
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Commit")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Text("Push")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct FileChangeRow: View {
    let filename: String
    let status: String

    var statusColor: Color {
        switch status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(status)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor)
                .frame(width: 14)

            Text(filename)
                .font(.system(size: 10))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Database Tool Card

struct DatabaseToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "cylinder")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                        .frame(width: 28, height: 28)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(6)

                    Text("Database")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Connected indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Provider
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Supabase Connected")
                            .font(.system(size: 11, weight: .medium))
                    }

                    // Tables list
                    VStack(alignment: .leading, spacing: 4) {
                        DatabaseTableRow(name: "users", rows: 124)
                        DatabaseTableRow(name: "posts", rows: 56)
                        DatabaseTableRow(name: "comments", rows: 892)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9))
                                Text("New Table")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DatabaseTableRow: View {
    let name: String
    let rows: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tablecells")
                .font(.system(size: 9))
                .foregroundColor(.cyan)

            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text("\(rows) rows")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Settings Tool Card

struct SettingsToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)

                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    SettingsRow(icon: "globe", title: "Domain", subtitle: "mysite.com")
                    SettingsRow(icon: "key", title: "Environment", subtitle: "3 variables")
                    SettingsRow(icon: "link", title: "Integrations", subtitle: "Supabase, Stripe")
                    SettingsRow(icon: "square.and.arrow.up", title: "Export", subtitle: "Download project")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Code Mode

/// Main Code editor view - shows project files
struct CodeView: View {
    @ObservedObject var client: APIClient
    @Binding var selectedPageId: String?

    var body: some View {
        HStack(spacing: 0) {
            // Code editor with selected page's HTML
            if let page = selectedPage {
                CodeEditor(code: .constant(page.html), language: "html")
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a file from sidebar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }

            Divider()

            // Live preview
            if let page = selectedPage {
                WebPreviewPane(html: page.html, projectId: client.currentProject?.id)
                    .frame(minWidth: 300)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "eye")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Preview")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minWidth: 300, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    private var selectedPage: Page? {
        guard let id = selectedPageId else { return nil }
        return client.pages.first { $0.id == id }
    }
}

// MARK: - Code Editor

struct CodeEditor: View {
    @Binding var code: String
    let language: String

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack {
                Text("index.html")
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)

                Spacer()
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Editor
            ScrollView {
                TextEditor(text: $code)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

// MARK: - Terminal

struct TerminalView: View {
    @Binding var output: String
    @State private var command = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Terminal")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.9))

            // Output
            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.9))

            // Input
            HStack {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)

                TextField("", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        output += "$ \(command)\n"
                        command = ""
                    }
            }
            .padding(8)
            .background(Color.black.opacity(0.9))
        }
    }
}

// MARK: - Web Preview

struct WebPreviewPane: View {
    let html: String
    var projectId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            // WebView
            HTMLWebView(html: html, projectId: projectId)
        }
    }
}

#Preview {
    CodeView(client: APIClient(), selectedPageId: .constant(nil))
        .frame(width: 1000, height: 600)
}

#Preview {
    AppRouter()
        .frame(width: 1200, height: 800)
}
