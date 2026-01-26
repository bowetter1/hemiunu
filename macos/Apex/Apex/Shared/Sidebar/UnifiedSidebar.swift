import SwiftUI

/// Unified sidebar showing files, components and assets
struct UnifiedSidebar: View {
    @ObservedObject var client: APIClient
    @ObservedObject var webSocket: WebSocketManager
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    let onNewProject: () -> Void
    let onClose: () -> Void
    var onProjectCreated: ((String) -> Void)? = nil

    @State private var componentsExpanded = false
    @State private var assetsExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Explorer")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onClose() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    // Files section
                    SidebarSection(title: "Pages", icon: "doc.text", isExpanded: .constant(true)) {
                        FilesTabContent(
                            client: client,
                            currentMode: currentMode,
                            selectedProjectId: $selectedProjectId,
                            selectedVariantId: $selectedVariantId,
                            selectedPageId: $selectedPageId,
                            onNewProject: onNewProject
                        )
                    }

                    // Components section (mockup)
                    SidebarSection(title: "Components", icon: "square.on.square", isExpanded: $componentsExpanded) {
                        VStack(alignment: .leading, spacing: 2) {
                            ComponentRow(name: "Navbar", icon: "rectangle.split.3x1")
                            ComponentRow(name: "Hero", icon: "rectangle")
                            ComponentRow(name: "Footer", icon: "rectangle.bottomhalf.filled")

                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("Add component")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }

                    // Assets section (mockup)
                    SidebarSection(title: "Assets", icon: "photo.on.rectangle", isExpanded: $assetsExpanded) {
                        VStack(alignment: .leading, spacing: 2) {
                            AssetRow(name: "logo.svg", icon: "doc.richtext")
                            AssetRow(name: "hero-bg.jpg", icon: "photo")
                            AssetRow(name: "icon-check.svg", icon: "doc.richtext")

                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("Upload")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Sidebar Section

struct SidebarSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}

// MARK: - Component Row (Mockup)

struct ComponentRow: View {
    let name: String
    let icon: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Asset Row (Mockup)

struct AssetRow: View {
    let name: String
    let icon: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            // Project dropdown for navigation
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
                    // Show root pages (no parent) with their children
                    ForEach(rootPages) { rootPage in
                        SidebarFileRow(
                            page: rootPage,
                            isSelected: selectedPageId == rootPage.id,
                            onSelect: { selectedPageId = rootPage.id },
                            isRoot: true
                        )

                        // Show child pages indented under this root
                        ForEach(childPages(for: rootPage.id)) { childPage in
                            SidebarFileRow(
                                page: childPage,
                                isSelected: selectedPageId == childPage.id,
                                onSelect: { selectedPageId = childPage.id },
                                isRoot: false
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()
        }
    }

    /// Root pages (pages without a parent - these are the layout/hero pages)
    private var rootPages: [Page] {
        client.pages.filter { $0.parentPageId == nil }
    }

    /// Child pages for a given parent page
    private func childPages(for parentId: String) -> [Page] {
        client.pages.filter { $0.parentPageId == parentId }
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
                        // Show variants with their pages
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

                        // Show pages without variant (layout pages and their children)
                        if !pagesWithoutVariant.isEmpty {
                            Divider()
                                .padding(.vertical, 8)

                            // Group by parent: show root pages first, then children under them
                            ForEach(rootLayoutPages) { layoutPage in
                                SidebarLayoutPageRow(
                                    page: layoutPage,
                                    childPages: childPagesFor(layoutPage.id),
                                    isSelected: selectedPageId == layoutPage.id,
                                    selectedPageId: $selectedPageId,
                                    onSelectPage: { pageId in
                                        selectedPageId = pageId
                                    }
                                )
                            }
                        }
                    } else {
                        // No variants - show pages grouped by parent
                        ForEach(rootLayoutPages) { layoutPage in
                            SidebarLayoutPageRow(
                                page: layoutPage,
                                childPages: childPagesFor(layoutPage.id),
                                isSelected: selectedPageId == layoutPage.id,
                                selectedPageId: $selectedPageId,
                                onSelectPage: { pageId in
                                    selectedPageId = pageId
                                }
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

    private var pagesWithoutVariant: [Page] {
        client.pages.filter { $0.variantId == nil }
    }

    /// Root layout pages (pages without a parent - these are layout/hero pages)
    private var rootLayoutPages: [Page] {
        client.pages.filter { $0.variantId == nil && $0.parentPageId == nil }
    }

    /// Child pages for a given parent layout page
    private func childPagesFor(_ parentId: String) -> [Page] {
        client.pages.filter { $0.parentPageId == parentId }
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
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))

            Text("Chat with AI")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Describe edits or ask questions")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
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
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholderText, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...6)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(12)
        .frame(minHeight: 60)
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
    var isRoot: Bool = true

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Tree connector for child pages
                if !isRoot {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 1)
                    }
                    .frame(width: 16, height: 20)
                }

                Image(systemName: isRoot ? "rectangle.3.group" : "doc.fill")
                    .font(.system(size: isRoot ? 11 : 10))
                    .foregroundColor(isRoot ? .orange : .blue.opacity(0.7))

                Text(fileName)
                    .font(.system(size: isRoot ? 12 : 11, weight: isRoot ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, isRoot ? 10 : 18)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
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

/// Layout page with expandable children (for Design mode)
struct SidebarLayoutPageRow: View {
    let page: Page
    let childPages: [Page]
    let isSelected: Bool
    @Binding var selectedPageId: String?
    let onSelectPage: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Layout/Hero page row
            Button(action: { onSelectPage(page.id) }) {
                HStack(spacing: 8) {
                    // Expand/collapse button (only if has children)
                    if !childPages.isEmpty {
                        Button(action: { isExpanded.toggle() }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 10)
                    }

                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)

                    Text(pageName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if !childPages.isEmpty {
                        Text("\(childPages.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Child pages (indented)
            if isExpanded && !childPages.isEmpty {
                VStack(spacing: 1) {
                    ForEach(Array(childPages.enumerated()), id: \.element.id) { index, child in
                        Button(action: { onSelectPage(child.id) }) {
                            HStack(spacing: 6) {
                                // Tree connector line
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 1)

                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 1)
                                }
                                .frame(width: 16, height: 20)

                                Image(systemName: "doc.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue.opacity(0.7))

                                Text(child.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                            .background(selectedPageId == child.id ? Color.blue.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
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

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Always visible 3-dot menu
            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(6)
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
        onNewProject: {},
        onClose: {}
    )
    .frame(height: 600)
}
