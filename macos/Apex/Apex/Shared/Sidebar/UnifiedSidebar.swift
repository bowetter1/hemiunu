import SwiftUI

/// Sidebar tab selection
enum SidebarTab: String, CaseIterable {
    case files = "Files"
    case chat = "Chat"
}

/// Unified sidebar with Files/Chat toggle (like Claude Code)
struct UnifiedSidebar: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    let onNewProject: () -> Void
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var selectedTab: SidebarTab = .chat

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            tabSelector
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // Content based on selected tab
            switch selectedTab {
            case .files:
                FilesTabContent(
                    client: client,
                    currentMode: currentMode,
                    selectedProjectId: $selectedProjectId,
                    selectedVariantId: $selectedVariantId,
                    selectedPageId: $selectedPageId,
                    onNewProject: onNewProject
                )
            case .chat:
                ChatTabContent(
                    client: client,
                    webSocket: webSocket,
                    selectedPageId: selectedPageId,
                    onProjectCreated: onProjectCreated
                )
            }
        }
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .files ? "folder" : "bubble.left.and.bubble.right")
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(9)
    }
}

// MARK: - Files Tab Content

struct FilesTabContent: View {
    @ObservedObject var client: APIClient
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Project dropdown
            projectDropdown
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if client.currentProject != nil {
                if currentMode == .code {
                    filesList
                } else {
                    variantsList
                }
            } else {
                projectsList
            }
        }
    }

    // MARK: - Project Dropdown

    private var projectDropdown: some View {
        Menu {
            ForEach(client.projects) { project in
                Button(action: { selectedProjectId = project.id }) {
                    HStack {
                        Circle()
                            .fill(statusColor(for: project))
                            .frame(width: 8, height: 8)
                        Text(projectTitle(project))
                        if project.id == client.currentProject?.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if client.currentProject != nil {
                Divider()
                Button(action: onNewProject) {
                    Label("Back to Projects", systemImage: "arrow.left")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let project = client.currentProject {
                    Circle()
                        .fill(statusColor(for: project))
                        .frame(width: 8, height: 8)
                    Text(projectTitle(project))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text("Select Project")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func projectTitle(_ project: Project) -> String {
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    private func statusColor(for project: Project) -> Color {
        switch project.status {
        case .brief, .clarification, .moodboard, .layouts:
            return .orange
        case .editing, .done:
            return .green
        case .failed:
            return .red
        }
    }

    // MARK: - Files List (Code mode)

    private var filesList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Files")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.pages) { page in
                        SidebarFileRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { selectedPageId = page.id }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    // MARK: - Variants List (Design mode)

    private var variantsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pages")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    if !client.variants.isEmpty {
                        ForEach(client.variants) { variant in
                            SidebarVariantRow(
                                variant: variant,
                                pages: pagesForVariant(variant.id),
                                isSelected: selectedVariantId == variant.id,
                                selectedPageId: $selectedPageId,
                                onSelectVariant: {
                                    selectedVariantId = variant.id
                                    if let firstPage = pagesForVariant(variant.id).first {
                                        selectedPageId = firstPage.id
                                    }
                                },
                                onSelectPage: { pageId in
                                    selectedVariantId = variant.id
                                    selectedPageId = pageId
                                }
                            )
                        }
                    } else {
                        // Legacy layout pages
                        ForEach(legacyLayoutPages) { page in
                            SidebarPageRow(
                                page: page,
                                isSelected: selectedPageId == page.id,
                                onSelect: { selectedPageId = page.id }
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    private func pagesForVariant(_ variantId: String) -> [Page] {
        client.pages.filter { $0.variantId == variantId }
    }

    private var legacyLayoutPages: [Page] {
        client.pages.filter { $0.layoutVariant != nil }
            .sorted { ($0.layoutVariant ?? 0) < ($1.layoutVariant ?? 0) }
    }

    // MARK: - Projects List

    private var projectsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.projects) { project in
                        SidebarProjectRow(
                            project: project,
                            isSelected: selectedProjectId == project.id,
                            onSelect: { selectedProjectId = project.id },
                            onDelete: {
                                Task {
                                    try? await client.deleteProject(projectId: project.id)
                                    if selectedProjectId == project.id {
                                        selectedProjectId = nil
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(8)
            }

            Spacer()

            // New project button
            Button(action: onNewProject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("New Project")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.1))
        }
    }
}

// MARK: - Chat Tab Content

struct ChatTabContent: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    var selectedPageId: String? = nil
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var messagesByPage: [String: [ChatMessage]] = [:]
    @State private var globalMessages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var clarificationQuestion: String?
    @State private var clarificationOptions: [String] = []

    private var selectedPage: Page? {
        if let pageId = selectedPageId {
            return client.pages.first { $0.id == pageId }
        }
        return client.pages.first { $0.layoutVariant == nil }
    }

    private var messages: [ChatMessage] {
        if let pageId = selectedPageId {
            return messagesByPage[pageId] ?? []
        }
        return globalMessages
    }

    private func addMessage(_ message: ChatMessage) {
        if let pageId = selectedPageId {
            if messagesByPage[pageId] == nil {
                messagesByPage[pageId] = []
            }
            messagesByPage[pageId]?.append(message)
        } else {
            globalMessages.append(message)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader

            Divider()

            // Messages
            messagesView

            Divider()

            // Input
            chatInput
        }
        .onChange(of: client.currentProject?.id) { _, _ in
            checkForClarification()
        }
        .onChange(of: webSocket.lastEvent) { _, event in
            handleWebSocketEvent(event)
        }
        .onAppear {
            checkForClarification()
        }
    }

    private func checkForClarification() {
        guard let project = client.currentProject,
              project.status == .clarification,
              let clarification = project.clarification,
              let question = clarification.question,
              let options = clarification.options,
              !options.isEmpty else {
            return
        }
        clarificationQuestion = question
        clarificationOptions = options
    }

    private var statusHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("AI Assistant")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let project = client.currentProject {
                Text(statusText(for: project.status))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    private func statusText(for status: ProjectStatus) -> String {
        switch status {
        case .brief: return "Starting..."
        case .clarification: return "Need info"
        case .moodboard: return "Moodboard ready"
        case .layouts: return "Layouts ready"
        case .editing: return "Ready"
        case .done: return "Done"
        case .failed: return "Error"
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty {
                        welcomeMessage
                    }

                    ForEach(messages) { message in
                        SidebarChatBubble(message: message)
                            .id(message.id)
                    }

                    if let question = clarificationQuestion, !clarificationOptions.isEmpty {
                        clarificationView(question: question, options: clarificationOptions)
                    }

                    if isLoading {
                        loadingIndicator
                    }
                }
                .padding(12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(.blue.opacity(0.5))

            Text("Describe your website")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("I'll design and build it")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text("Thinking...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }

    private func clarificationView(question: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(10)

            ForEach(options, id: \.self) { option in
                Button(action: { selectClarificationOption(option) }) {
                    Text(option)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chatInput: some View {
        HStack(spacing: 8) {
            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...3)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(10)
    }

    private var placeholderText: String {
        if let project = client.currentProject {
            if project.status == .clarification {
                return "Type your answer..."
            } else if !client.pages.isEmpty {
                if let page = selectedPage {
                    return "Edit \(page.name)..."
                }
                return "Select a page..."
            } else {
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText
        inputText = ""

        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        addMessage(userMessage)
        isLoading = true

        if let project = client.currentProject {
            if project.status == .clarification {
                selectClarificationOption(text)
            } else if !client.pages.isEmpty {
                editPage(instruction: text)
            } else {
                isLoading = false
                let response = ChatMessage(role: .assistant, content: "Please wait while I generate...", timestamp: Date())
                addMessage(response)
            }
        } else {
            createProject(brief: text)
        }
    }

    private func createProject(brief: String) {
        Task {
            do {
                let project = try await client.createProject(brief: brief)
                await MainActor.run {
                    isLoading = false
                    onProjectCreated?(project.id)
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Creating your website. First, I'll generate moodboard options...",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            }
        }
    }

    private func editPage(instruction: String) {
        guard let project = client.currentProject,
              let page = selectedPage else {
            isLoading = false
            let response = ChatMessage(role: .assistant, content: "Select a page first.", timestamp: Date())
            addMessage(response)
            return
        }

        Task {
            do {
                let updated = try await client.editPage(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction
                )

                await MainActor.run {
                    if let index = client.pages.firstIndex(where: { $0.id == page.id }) {
                        client.pages[index] = updated
                    }
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Done! Updated to v\(updated.currentVersion).",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            }
        }
    }

    private func selectClarificationOption(_ option: String) {
        guard let projectId = client.currentProject?.id else { return }

        let userMessage = ChatMessage(role: .user, content: option, timestamp: Date())
        addMessage(userMessage)

        clarificationQuestion = nil
        clarificationOptions = []
        isLoading = true

        Task {
            do {
                let _ = try await client.clarifyProject(projectId: projectId, answer: option)
                await MainActor.run {
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Got it! Searching for \(option) brand info...",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let response = ChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    addMessage(response)
                }
            }
        }
    }

    private func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event else { return }

        switch event {
        case .clarificationNeeded(let question, let options):
            isLoading = false
            clarificationQuestion = question
            clarificationOptions = options
            let response = ChatMessage(
                role: .assistant,
                content: "I need some clarification:",
                timestamp: Date()
            )
            addMessage(response)

        case .moodboardReady:
            clarificationQuestion = nil
            clarificationOptions = []
            let response = ChatMessage(
                role: .assistant,
                content: "Created 3 moodboard options. Select one to continue.",
                timestamp: Date()
            )
            addMessage(response)
            Task {
                if let projectId = client.currentProject?.id {
                    let project = try? await client.getProject(id: projectId)
                    await MainActor.run {
                        client.currentProject = project
                    }
                }
            }

        case .error(let message):
            isLoading = false
            let response = ChatMessage(
                role: .assistant,
                content: "Error: \(message)",
                timestamp: Date()
            )
            addMessage(response)

        default:
            break
        }
    }
}

// MARK: - Sidebar Components

struct SidebarChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 20) }

            Text(message.content)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(message.role == .user ? Color.blue : Color(nsColor: .windowBackgroundColor))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }
}

struct SidebarFileRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var fileName: String {
        page.name.lowercased().replacingOccurrences(of: " ", with: "-") + ".html"
    }
}

struct SidebarVariantRow: View {
    let variant: Variant
    let pages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectVariant: () -> Void
    let onSelectPage: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                onSelectVariant()
                isExpanded = true
            }) {
                HStack(spacing: 8) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "paintpalette")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .blue : .secondary)

                    Text(variant.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(pages.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected && selectedPageId == nil ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(pages) { page in
                        SidebarPageRow(
                            page: page,
                            isSelected: selectedPageId == page.id,
                            onSelect: { onSelectPage(page.id) }
                        )
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 4)
            }
        }
    }
}

struct SidebarPageRow: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(pageName)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if page.currentVersion > 1 {
                    Text("v\(page.currentVersion)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    var pageName: String {
        if let variant = page.layoutVariant {
            return "Layout \(variant)"
        }
        return page.name
    }
}

struct SidebarProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(projectTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isHovering {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }

    var projectTitle: String {
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: project.createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return ""
    }

    var statusColor: Color {
        switch project.status {
        case .brief, .clarification, .moodboard, .layouts:
            return .orange
        case .editing, .done:
            return .green
        case .failed:
            return .red
        }
    }
}

#Preview {
    UnifiedSidebar(
        client: APIClient(),
        webSocket: WebSocketManager(),
        currentMode: .design,
        selectedProjectId: .constant(nil),
        selectedVariantId: .constant(nil),
        selectedPageId: .constant(nil),
        onNewProject: {}
    )
    .frame(height: 600)
}
