import SwiftUI
import UniformTypeIdentifiers

struct StartProjectSheet: View {
    @Binding var isPresented: Bool
    let client: APIClient
    let boss: BossCoordinator?
    let onProjectCreated: (String) -> Void

    // Form state
    @State private var projectName = ""
    @State private var briefText: String
    @State private var websiteURL = ""
    @State private var selectedImage: NSImage?
    @State private var isDraggingOver = false
    @State private var isCreating = false

    // Generation config
    @State private var config = GenerationConfig()
    @State private var selectedImageSource: ImageSource = .auto

    // Model selection (boss mode)
    @State private var useClaude = true
    @State private var useGemini = false
    @State private var useKimi = false

    private var selectedAgents: [AIAgent] {
        var agents: [AIAgent] = []
        if useClaude { agents.append(.claude) }
        if useGemini { agents.append(.gemini) }
        if useKimi { agents.append(.kimi) }
        return agents
    }

    private var useBoss: Bool { !selectedAgents.isEmpty }

    init(isPresented: Binding<Bool>, client: APIClient, boss: BossCoordinator? = nil, initialBrief: String = "", onProjectCreated: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.client = client
        self.boss = boss
        self._briefText = State(initialValue: initialBrief)
        self.onProjectCreated = onProjectCreated
    }

    private enum ImageSource: String, CaseIterable, Identifiable {
        case auto = "auto"
        case none = "none"
        case existingImages = "existing_images"
        case img2img = "img2img"
        case ai = "ai"
        case stock = "stock"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto: return "AI chooses"
            case .none: return "No images"
            case .existingImages: return "Existing (from site)"
            case .img2img: return "Img2img (restyle)"
            case .ai: return "AI generated"
            case .stock: return "Stock photos"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Start Project")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isCreating)
            }
            .padding()

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Project name
                    sectionLabel("Project Name", icon: "tag")
                    TextField("e.g. Fjällräven", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    // Brief
                    sectionLabel("Description", icon: "text.alignleft")
                    TextField("What do you want to build?", text: $briefText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(3...5)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    // URL
                    sectionLabel("Reference URL", icon: "link")
                    TextField("https://example.com", text: $websiteURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    Divider()

                    // Image source
                    sectionLabel("Image Source", icon: "photo.on.rectangle")
                    Picker("", selection: $selectedImageSource) {
                        ForEach(ImageSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    Divider()

                    // Research toggles
                    sectionLabel("Research", icon: "magnifyingglass")

                    toggleRow(
                        title: "Web search for company",
                        description: "Searches the web to find the company website",
                        isOn: $config.webSearchCompany
                    )
                    toggleRow(
                        title: "Scrape company site",
                        description: "Extracts brand colors and images from their site",
                        isOn: $config.scrapeCompanySite
                    )
                    toggleRow(
                        title: "Find inspiration sites",
                        description: "Finds \(config.inspirationSiteCount) inspiration sites + competitors",
                        isOn: $config.findInspirationSites
                    )

                    Divider()

                    // Generation toggles
                    sectionLabel("Generation", icon: "sparkles")

                    toggleRow(
                        title: "Direct to research",
                        description: "Skip clarification questions and start building",
                        isOn: $config.skipClarification
                    )
                    toggleRow(
                        title: "Web search during layout",
                        description: "Allow the AI to search while building layouts",
                        isOn: $config.webSearchDuringLayout
                    )


                    Divider()

                    // Local build — model selection
                    sectionLabel("Local Build", icon: "brain")

                    toggleRow(
                        title: "Claude",
                        description: "Claude Opus builds locally on your Mac",
                        isOn: $useClaude
                    )
                    .disabled(!BossService.isAvailable(agent: .claude))

                    toggleRow(
                        title: "Gemini",
                        description: "Gemini CLI builds in parallel",
                        isOn: $useGemini
                    )
                    .disabled(!BossService.isAvailable(agent: .gemini))

                    toggleRow(
                        title: "Kimi",
                        description: "Kimi CLI builds in parallel",
                        isOn: $useKimi
                    )
                    .disabled(!BossService.isAvailable(agent: .kimi))

                    // Two-phase info text
                    if selectedAgents.count > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Claude researches first, then all agents build in parallel")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    }

                    // Image upload
                    sectionLabel("Inspiration", icon: "photo")
                    imageDropZone
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()

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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(canCreate ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate || isCreating)
            }
            .padding()
        }
        .frame(width: 480, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !briefText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var imageDropZone: some View {
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

    // MARK: - Actions

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

        if useBoss {
            createBossProject(brief: enhancedBrief)
        } else {
            createServerProject(brief: enhancedBrief)
        }
    }

    /// Encode the selected NSImage as a base64 JPEG string
    private func encodeInspirationImage() -> String? {
        guard let image = selectedImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }

    /// Server-side project creation (original flow)
    private func createServerProject(brief: String) {
        let finalConfig = config
        let imageBase64 = encodeInspirationImage()

        Task {
            do {
                let project = try await client.projectService.create(
                    brief: brief,
                    imageSource: selectedImageSource.rawValue,
                    config: finalConfig,
                    inspirationImageBase64: imageBase64
                )
                await MainActor.run {
                    isCreating = false
                    isPresented = false
                    onProjectCreated(project.id)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }

    /// Boss mode project creation — activates boss coordinator with selected agents
    private func createBossProject(brief: String) {
        guard let boss else { return }
        let agents = selectedAgents
        let vectors = Array(repeating: nil as String?, count: agents.count)

        // Build enriched prompt with config instructions
        var prompt = brief

        // Research instructions from toggles
        var researchNotes: [String] = []
        if !config.webSearchCompany {
            researchNotes.append("Do NOT web search for the company — use only the provided URL")
        }
        if !config.scrapeCompanySite {
            researchNotes.append("Do NOT visit or scrape the company website")
        }
        if !config.findInspirationSites {
            researchNotes.append("Skip searching for inspiration sites")
        }
        if config.skipClarification {
            researchNotes.append("Do NOT ask any clarification questions — go straight to work")
        }
        if !researchNotes.isEmpty {
            prompt += "\n\nResearch instructions:\n" + researchNotes.map { "- \($0)" }.joined(separator: "\n")
        }

        // Image source instruction
        let imgInstruction = imageSourceInstruction

        // For solo mode, also append build instructions to the prompt
        if agents.count == 1 {
            var buildNotes: [String] = []
            if let img = imgInstruction { buildNotes.append(img) }
            if !config.webSearchDuringLayout {
                buildNotes.append("Do NOT search the web while building layouts")
            }
            if selectedImage != nil {
                buildNotes.append("See inspiration.jpg in the workspace for visual reference")
            }
            if !buildNotes.isEmpty {
                prompt += "\n\nBuild instructions:\n" + buildNotes.map { "- \($0)" }.joined(separator: "\n")
            }
        }

        boss.activate(count: agents.count, vectors: vectors, agents: agents)

        // Store build-phase config for checklist generation + builder messages
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        boss.configureBuild(
            config: config,
            imageInstruction: imgInstruction,
            inspirationImage: selectedImage,
            projectName: trimmedName.isEmpty ? nil : trimmedName
        )

        isPresented = false
        // Small delay to let the sheet dismiss, then send
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            boss.send(prompt, setLoading: { _ in })
        }
    }

    /// Map image source picker to a human-readable instruction for the agent
    private var imageSourceInstruction: String? {
        switch selectedImageSource {
        case .auto: return nil
        case .none: return "Do not use any images in the design"
        case .existingImages: return "Download and use images from the existing site"
        case .img2img: return "Use img2img (apex_img2img) to restyle reference images from the site"
        case .ai: return "Generate all images with AI (apex_generate_image)"
        case .stock: return "Use stock photos only (apex_search_photos from Pexels)"
        }
    }
}
