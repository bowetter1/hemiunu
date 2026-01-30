import SwiftUI
import UniformTypeIdentifiers

struct StartProjectSheet: View {
    @Binding var isPresented: Bool
    let client: APIClient
    let onProjectCreated: (String) -> Void

    // Form state
    @State private var briefText: String
    @State private var websiteURL = ""
    @State private var selectedImage: NSImage?
    @State private var isDraggingOver = false
    @State private var isCreating = false
    @State private var showAdvanced = false

    // Generation config
    @State private var config = GenerationConfig()
    @State private var selectedImageSource: ImageSource = .ai

    init(isPresented: Binding<Bool>, client: APIClient, initialBrief: String = "", onProjectCreated: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.client = client
        self._briefText = State(initialValue: initialBrief)
        self.onProjectCreated = onProjectCreated
    }

    private enum ImageSource: String, CaseIterable, Identifiable {
        case none = "none"
        case existingImages = "existing_images"
        case img2img = "img2img"
        case ai = "ai"
        case stock = "stock"

        var id: String { rawValue }

        var title: String {
            switch self {
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
                        description: "Searches for award-winning sites in the industry",
                        isOn: $config.findInspirationSites
                    )
                    if config.findInspirationSites {
                        HStack {
                            Text("Inspiration site count")
                                .font(.system(size: 12))
                            Spacer()
                            Stepper("\(config.inspirationSiteCount)", value: $config.inspirationSiteCount, in: 1...6)
                                .font(.system(size: 11))
                                .frame(width: 100)
                        }
                        .padding(.leading, 4)
                    }

                    Divider()

                    // Generation toggles
                    sectionLabel("Generation", icon: "sparkles")

                    toggleRow(
                        title: "Skip clarification questions",
                        description: "Go straight to research without asking questions",
                        isOn: $config.skipClarification
                    )
                    toggleRow(
                        title: "Web search during layout",
                        description: "Allow the AI to search while building layouts",
                        isOn: $config.webSearchDuringLayout
                    )

                    // Layout count picker
                    HStack {
                        Text("Layout count")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("", selection: $config.layoutCount) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding(.leading, 4)

                    // Layout provider (Opus vs OpenAI)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Layout AI")
                                .font(.system(size: 12, weight: .medium))
                            Text("Which AI creates the HTML layout")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $config.layoutProvider) {
                            Text("Claude").tag("anthropic")
                            Text("OpenAI").tag("openai")
                        }
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        .font(.system(size: 11))
                    }
                    .padding(.leading, 4)

                    // Advanced section
                    if showAdvanced {
                        Divider()
                        sectionLabel("Models", icon: "cpu")

                        HStack {
                            Text("Research model")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $config.researchModel) {
                                Text("Haiku").tag("haiku")
                                Text("Sonnet").tag("sonnet")
                            }
                            .frame(width: 120)
                        }
                        .padding(.leading, 4)

                        HStack {
                            Text("Layout model")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $config.layoutModel) {
                                Text("Sonnet").tag("sonnet")
                                Text("Opus").tag("opus")
                            }
                            .frame(width: 120)
                        }
                        .padding(.leading, 4)
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
                Button(action: { withAnimation { showAdvanced.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                        Text("Advanced")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

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
                    .background(canCreate ? Color.orange : Color.gray)
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
        if selectedImage != nil {
            enhancedBrief += "\n\n(User provided an inspiration image)"
        }

        // Sync image source into config
        var finalConfig = config
        // Image source is sent as top-level param, config carries the rest

        Task {
            do {
                let project = try await client.projectService.create(
                    brief: enhancedBrief,
                    imageSource: selectedImageSource.rawValue,
                    config: finalConfig
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
}
