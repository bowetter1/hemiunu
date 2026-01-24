import SwiftUI

// MARK: - App Mode

enum AppMode: String, CaseIterable {
    case design = "Design"
    case code = "Code"
    case text = "Text"
}

struct ContentView: View {
    @StateObject private var client = ApexClient()
    @StateObject private var wsClient = WebSocketClient()
    @State private var commandText: String = ""
    @State private var isConnected = false
    @State private var errorMessage: String?
    @State private var selectedLayoutVariant: Int? = nil
    @State private var selectedMoodboardVariant: Int? = nil
    @State private var selectedMode: AppMode = .design
    @State private var selectedProjectId: String? = nil
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if showSidebar {
                ProjectsSidebar(
                    client: client,
                    selectedProjectId: $selectedProjectId,
                    onNewProject: startNewProject
                )
                .onChange(of: selectedProjectId) { _, newId in
                    if let id = newId {
                        loadProject(id: id)
                    }
                }

                Divider()
            }

            // Main content area
            ZStack {
                // Background
                Color(nsColor: .windowBackgroundColor)
                    .edgesIgnoringSafeArea(.all)

                // Grid Background
                SimpleGridView()

                // Main Content based on mode and project status
                VStack(spacing: 0) {
                    // Mode Switcher
                    modeSwitcher
                        .padding(.top, 12)

                    Spacer()

                    // Content based on selected mode
                    switch selectedMode {
                    case .design:
                        mainContent
                    case .code:
                        codeContent
                    case .text:
                        textContent
                    }

                    Spacer()
                }

                // Fixed UI Overlays
                VStack {
                    HStack {
                        // Toggle sidebar button
                        Button(action: { withAnimation { showSidebar.toggle() } }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding()

                        // Connection/Status indicator
                        statusIndicator

                        Spacer()

                        // Logs panel
                        if client.currentProject != nil {
                            LogsPanel(logs: client.projectLogs)
                                .padding()
                        }
                    }
                    Spacer()

                    // Command Bar (only show when connected)
                    if isConnected {
                        CommandBar(
                            text: $commandText,
                            placeholder: placeholderText
                        ) {
                            processCommand()
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            connectToServer()
        }
        .onChange(of: wsClient.lastEvent) { _, newEvent in
            handleWebSocketEvent(newEvent)
        }
    }

    // MARK: - Project Actions

    func startNewProject() {
        // Clear current project to show welcome view
        client.currentProject = nil
        client.pages = []
        client.projectLogs = []
        selectedProjectId = nil
        selectedMoodboardVariant = nil
        selectedLayoutVariant = nil
        wsClient.disconnect()
    }

    func loadProject(id: String) {
        Task {
            do {
                let project = try await client.getProject(id: id)
                await MainActor.run {
                    client.currentProject = project
                    selectedMoodboardVariant = project.selectedMoodboard
                    selectedLayoutVariant = project.selectedLayout
                }

                // Load pages
                let pages = try await client.getPages(projectId: id)
                await MainActor.run {
                    client.pages = pages
                }

                // Load logs
                let logs = try await client.getProjectLogs(projectId: id)
                await MainActor.run {
                    client.projectLogs = logs
                }

                // Connect WebSocket for real-time updates
                if let token = client.authToken {
                    wsClient.connect(projectId: id, token: token)
                }
            } catch {
                print("Failed to load project: \(error)")
            }
        }
    }

    // MARK: - Mode Switcher

    var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: selectedMode == mode ? .semibold : .regular))
                        .foregroundColor(selectedMode == mode ? .white : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            selectedMode == mode
                                ? Color.blue
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Code Content

    @ViewBuilder
    var codeContent: some View {
        if let page = client.pages.first(where: { $0.layoutVariant == nil }) {
            CodeEditorView(html: page.html)
        } else if let project = client.currentProject, !project.moodboards.isEmpty {
            // Show moodboard info
            CodeEditorView(html: moodboardsAsCode(project.moodboards))
        } else {
            VStack(spacing: 20) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("No code yet")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Create a project in Design mode first")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(60)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    func moodboardsAsCode(_ moodboards: [Moodboard]) -> String {
        var result = "// Moodboard Data\n\n"
        for (i, mb) in moodboards.enumerated() {
            result += "/* \(i + 1). \(mb.name) */\n"
            result += ":root {\n"
            for (j, color) in mb.palette.enumerated() {
                result += "  --color-\(j + 1): \(color);\n"
            }
            result += "  --font-heading: '\(mb.fonts.heading)';\n"
            result += "  --font-body: '\(mb.fonts.body)';\n"
            result += "}\n\n"
        }
        return result
    }

    // MARK: - Text Content

    @ViewBuilder
    var textContent: some View {
        if let page = client.pages.first(where: { $0.layoutVariant == nil }) {
            TextEditorView(html: page.html)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("No text yet")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Create a project in Design mode first")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(60)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    var mainContent: some View {
        if let project = client.currentProject {
            switch project.status {
            case .brief:
                // Waiting for moodboard generation
                GeneratingView(message: "Generating moodboard...")

            case .moodboard:
                // Show 3 moodboard alternatives
                if !project.moodboards.isEmpty {
                    MoodboardsView(
                        moodboards: project.moodboards,
                        selectedVariant: $selectedMoodboardVariant
                    ) {
                        selectMoodboard()
                    }
                } else {
                    GeneratingView(message: "Loading moodboards...")
                }

            case .layouts:
                // Show 3 layout alternatives
                LayoutsView(
                    pages: client.pages,
                    selectedVariant: $selectedLayoutVariant
                ) {
                    selectLayout()
                }

            case .editing, .done:
                // Show the live preview
                if let mainPage = client.pages.first(where: { $0.layoutVariant == nil }) {
                    LivePreview(html: mainPage.html)
                } else if let previewHTML = client.previewHTML {
                    LivePreview(html: previewHTML)
                } else {
                    GeneratingView(message: "Loading...")
                }

            case .failed:
                ErrorView(message: project.errorMessage ?? "An error occurred")
            }
        } else {
            // No project - show welcome
            WelcomeView()
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    var statusIndicator: some View {
        HStack {
            if !isConnected {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let project = client.currentProject {
                Circle()
                    .fill(statusColor(for: project.status))
                    .frame(width: 8, height: 8)
                Text(statusText(for: project.status))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding()
    }

    var placeholderText: String {
        if let project = client.currentProject {
            switch project.status {
            case .editing, .done:
                return "Describe what you want to change..."
            default:
                return "Waiting..."
            }
        }
        return "Describe your website..."
    }

    // MARK: - Actions

    func connectToServer() {
        Task {
            do {
                _ = try await client.getDevToken()
                await MainActor.run {
                    isConnected = true
                    errorMessage = nil
                }
                print("Connected to server!")

                // Fetch existing projects
                _ = try await client.listProjects()
                print("Loaded \(client.projects.count) projects")
            } catch {
                print("Failed to connect: \(error)")
                await MainActor.run {
                    errorMessage = "Cannot connect"
                }
            }
        }
    }

    func processCommand() {
        guard !commandText.isEmpty else { return }
        let text = commandText
        commandText = ""

        if let project = client.currentProject, project.status == .editing || project.status == .done {
            // Edit existing page
            editCurrentPage(instruction: text)
        } else {
            // Create new project
            createProject(brief: text)
        }
    }

    func createProject(brief: String) {
        Task {
            do {
                let project = try await client.createProject(brief: brief)
                print("Project created: \(project.id)")
                // Connect WebSocket for real-time updates
                connectWebSocket(projectId: project.id)
            } catch {
                print("Failed to create project: \(error)")
                await MainActor.run {
                    errorMessage = "Could not create project"
                }
            }
        }
    }

    func selectMoodboard() {
        guard let project = client.currentProject,
              let variant = selectedMoodboardVariant else { return }

        Task {
            do {
                let updated = try await client.selectMoodboard(projectId: project.id, variant: variant)
                await MainActor.run {
                    client.currentProject = updated
                }
                // WebSocket will notify when layouts are ready
            } catch {
                print("Failed to select moodboard: \(error)")
                await MainActor.run {
                    errorMessage = "Could not select moodboard"
                }
            }
        }
    }

    func selectLayout() {
        guard let project = client.currentProject,
              let variant = selectedLayoutVariant else { return }

        Task {
            do {
                let updated = try await client.selectLayout(projectId: project.id, variant: variant)
                await MainActor.run {
                    client.currentProject = updated
                }
                // Refresh pages
                let pages = try await client.getPages(projectId: project.id)
                await MainActor.run {
                    client.pages = pages
                    if let mainPage = pages.first(where: { $0.layoutVariant == nil }) {
                        client.previewHTML = mainPage.html
                    }
                }
            } catch {
                print("Failed to select layout: \(error)")
                await MainActor.run {
                    errorMessage = "Could not select layout"
                }
            }
        }
    }

    func editCurrentPage(instruction: String) {
        guard let project = client.currentProject,
              let page = client.pages.first(where: { $0.layoutVariant == nil }) else { return }

        Task {
            do {
                let updated = try await client.editPage(
                    projectId: project.id,
                    pageId: page.id,
                    instruction: instruction
                )
                await MainActor.run {
                    // Update the page in the list
                    if let index = client.pages.firstIndex(where: { $0.id == page.id }) {
                        client.pages[index] = updated
                    }
                    client.previewHTML = updated.html
                }
            } catch {
                print("Failed to edit page: \(error)")
                await MainActor.run {
                    errorMessage = "Could not edit"
                }
            }
        }
    }

    func connectWebSocket(projectId: String) {
        guard let token = client.authToken else {
            print("No auth token for WebSocket")
            return
        }

        // Connect (events are handled via onChange of wsClient.lastEvent)
        wsClient.connect(projectId: projectId, token: token)
    }

    func handleWebSocketEvent(_ event: WebSocketEvent?) {
        guard let event = event,
              let projectId = client.currentProject?.id else { return }

        Task {
            switch event {
            case .moodboardReady:
                // Refresh project to get moodboards
                if let project = try? await client.getProject(id: projectId) {
                    await MainActor.run {
                        client.currentProject = project
                        if selectedMoodboardVariant == nil && !project.moodboards.isEmpty {
                            selectedMoodboardVariant = 1
                        }
                    }
                }
                if let logs = try? await client.getProjectLogs(projectId: projectId) {
                    await MainActor.run {
                        client.projectLogs = logs
                    }
                }

            case .layoutsReady(let count):
                print("Layouts ready: \(count)")
                if let project = try? await client.getProject(id: projectId) {
                    await MainActor.run {
                        client.currentProject = project
                    }
                }
                if let pages = try? await client.getPages(projectId: projectId) {
                    await MainActor.run {
                        client.pages = pages
                        if selectedLayoutVariant == nil && !pages.isEmpty {
                            selectedLayoutVariant = 1
                        }
                    }
                }
                if let logs = try? await client.getProjectLogs(projectId: projectId) {
                    await MainActor.run {
                        client.projectLogs = logs
                    }
                }

            case .error(let message):
                await MainActor.run {
                    errorMessage = message
                }

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .brief, .moodboard, .layouts: return .orange
        case .editing, .done: return .green
        case .failed: return .red
        }
    }

    func statusText(for status: ProjectStatus) -> String {
        switch status {
        case .brief: return "Creating moodboard..."
        case .moodboard: return "Moodboard ready"
        case .layouts: return "Choose layout"
        case .editing: return "Editing"
        case .done: return "Done"
        case .failed: return "Error"
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            // Logo
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("What do you want to build?")
                    .font(.system(size: 28, weight: .bold))

                Text("Describe your website and we'll generate it for you")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            // Example prompts
            VStack(spacing: 8) {
                ExamplePrompt(text: "A landing page for my coffee shop")
                ExamplePrompt(text: "Portfolio site for a photographer")
                ExamplePrompt(text: "SaaS pricing page with 3 tiers")
            }
            .padding(.top, 8)
        }
        .padding(48)
    }
}

struct ExamplePrompt: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 12))
                .foregroundColor(.blue)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(20)
    }
}

// MARK: - Generating View

struct GeneratingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding(60)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Something went wrong")
                .font(.title)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(60)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Moodboards View (3 alternatives)

struct MoodboardsView: View {
    let moodboards: [Moodboard]
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Design Style")
                .font(.title)
                .fontWeight(.bold)

            HStack(spacing: 20) {
                ForEach(Array(moodboards.enumerated()), id: \.offset) { index, moodboard in
                    MoodboardOptionCard(
                        moodboard: moodboard,
                        variant: index + 1,
                        isSelected: selectedVariant == index + 1
                    ) {
                        selectedVariant = index + 1
                    }
                }
            }

            if selectedVariant != nil {
                Button(action: onSelect) {
                    Text("Select & Create Layouts")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(40)
    }
}

struct MoodboardOptionCard: View {
    let moodboard: Moodboard
    let variant: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Name
            Text(moodboard.name)
                .font(.headline)
                .fontWeight(.bold)

            // Color palette
            HStack(spacing: 4) {
                ForEach(moodboard.palette, id: \.self) { hex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                }
            }

            // Fonts
            VStack(spacing: 2) {
                Text(moodboard.fonts.heading)
                    .font(.system(size: 14, weight: .semibold))
                Text(moodboard.fonts.body)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Mood keywords
            HStack(spacing: 4) {
                ForEach(moodboard.mood.prefix(3), id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }

            // Rationale
            Text(moodboard.rationale)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(width: 220)
        .padding(20)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Layouts View

struct LayoutsView: View {
    let pages: [Page]
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    var layoutPages: [Page] {
        pages.filter { $0.layoutVariant != nil }.sorted { ($0.layoutVariant ?? 0) < ($1.layoutVariant ?? 0) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Layout")
                .font(.title)
                .fontWeight(.bold)

            if layoutPages.isEmpty {
                GeneratingView(message: "Generating 3 layouts...")
            } else {
                HStack(spacing: 20) {
                    ForEach(layoutPages, id: \.id) { page in
                        LayoutCard(
                            page: page,
                            isSelected: selectedVariant == page.layoutVariant
                        ) {
                            selectedVariant = page.layoutVariant
                        }
                    }
                }

                if selectedVariant != nil {
                    Button(action: onSelect) {
                        Text("Select Layout \(selectedVariant!)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(40)
    }
}

struct LayoutCard: View {
    let page: Page
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack {
            // Mini preview
            WebViewNode(htmlContent: page.html)
                .frame(width: 250, height: 180)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )

            Text(page.name)
                .font(.headline)

            Text("Layout \(page.layoutVariant ?? 0)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Live Preview

struct LivePreview: View {
    let html: String

    var body: some View {
        VStack(spacing: 12) {
            // Browser Chrome
            BrowserChrome()

            // WebView with live HTML
            WebViewNode(htmlContent: html)
                .frame(width: 800, height: 600)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 40)
    }
}

// MARK: - Browser Chrome

struct BrowserChrome: View {
    var body: some View {
        HStack {
            Circle().fill(Color.red).frame(width: 12, height: 12)
            Circle().fill(Color.yellow).frame(width: 12, height: 12)
            Circle().fill(Color.green).frame(width: 12, height: 12)
            Spacer()
            Text("preview.apex.app")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: "plus")
        }
        .padding(.horizontal)
        .frame(width: 800, height: 40)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Logs Panel

struct LogsPanel: View {
    let logs: [ProjectLog]

    // Define the steps
    let steps = ["Moodboard", "Layouts", "Editing"]

    var completedSteps: Set<String> {
        var completed = Set<String>()
        for log in logs {
            if log.phase == "moodboard" && log.message.contains("Created") {
                completed.insert("Moodboard")
            }
            if log.phase == "layouts" && log.message.contains("Created") {
                completed.insert("Layouts")
            }
            if log.phase == "edit" {
                completed.insert("Editing")
            }
        }
        return completed
    }

    var currentStep: String? {
        if let lastLog = logs.first {
            switch lastLog.phase {
            case "moodboard": return "Moodboard"
            case "layouts": return "Layouts"
            case "edit": return "Editing"
            default: return nil
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(steps, id: \.self) { step in
                HStack(spacing: 8) {
                    Image(systemName: completedSteps.contains(step) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(completedSteps.contains(step) ? .green : .secondary)
                        .font(.system(size: 14))

                    Text(step)
                        .font(.system(size: 12, weight: completedSteps.contains(step) ? .medium : .regular))
                        .foregroundColor(completedSteps.contains(step) ? .primary : .secondary)

                    if currentStep == step && !completedSteps.contains(step) {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Code Editor View

struct CodeEditorView: View {
    let html: String
    @State private var selectedTab: String = "HTML"

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(["HTML", "CSS", "All"], id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.blue.opacity(0.8) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(displayedCode, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            // Code content
            ScrollView {
                Text(displayedCode)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 700, height: 500)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 20)
    }

    var displayedCode: String {
        switch selectedTab {
        case "CSS":
            return extractCSS(from: html)
        case "HTML":
            return extractHTML(from: html)
        default:
            return html
        }
    }

    func extractCSS(from html: String) -> String {
        // Extract content between <style> tags
        guard let styleStart = html.range(of: "<style>"),
              let styleEnd = html.range(of: "</style>") else {
            return "// No CSS found"
        }
        return String(html[styleStart.upperBound..<styleEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractHTML(from html: String) -> String {
        // Remove style content for cleaner HTML view
        var result = html
        if let styleStart = html.range(of: "<style>"),
           let styleEnd = html.range(of: "</style>") {
            let fullStyleRange = styleStart.lowerBound..<styleEnd.upperBound
            result = html.replacingCharacters(in: fullStyleRange, with: "<style>/* ... */</style>")
        }
        return result
    }
}

// MARK: - Text Editor View

struct TextEditorView: View {
    let html: String
    @State private var extractedTexts: [ExtractedText] = []

    struct ExtractedText: Identifiable {
        let id = UUID()
        let tag: String
        let content: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Text Content")
                    .font(.headline)
                Spacer()
                Text("\(extractedTexts.count) elements")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // Text list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(extractedTexts) { text in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text.tag.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)

                            Text(text.content)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 20)
        .onAppear {
            extractedTexts = extractTexts(from: html)
        }
    }

    func extractTexts(from html: String) -> [ExtractedText] {
        var results: [ExtractedText] = []
        let tags = ["h1", "h2", "h3", "h4", "p", "button", "a", "span", "li"]

        for tag in tags {
            let pattern = "<\(tag)[^>]*>([^<]+)</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)

                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty && content.count > 1 {
                            results.append(ExtractedText(tag: tag, content: content))
                        }
                    }
                }
            }
        }
        return results
    }
}

#Preview {
    ContentView()
}
