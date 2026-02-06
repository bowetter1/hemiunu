import SwiftUI
import UniformTypeIdentifiers

struct StartProjectSheet: View {
    @Binding var isPresented: Bool
    let chatViewModel: ChatViewModel
    var initialBrief: String = ""
    let onProjectCreated: (String) -> Void

    // Form state
    @State private var projectName = ""
    @State private var briefText: String
    @State private var websiteURL = ""
    @State private var selectedImage: NSImage?
    @State private var isDraggingOver = false
    @State private var isCreating = false

    // AI provider
    @State private var selectedProvider: AIProvider = .groq

    init(isPresented: Binding<Bool>, chatViewModel: ChatViewModel, initialBrief: String = "", onProjectCreated: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.chatViewModel = chatViewModel
        self._briefText = State(initialValue: initialBrief)
        self.onProjectCreated = onProjectCreated
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
                    TextField("e.g. Fjallraven", text: $projectName)
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

                    // AI Provider
                    sectionLabel("AI Provider", icon: "brain")
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

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
        .frame(width: 480, height: 520)
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

        var prompt = briefText
        if !websiteURL.isEmpty {
            prompt += "\n\nReference website: \(websiteURL)"
        }

        // Set provider before sending
        chatViewModel.appState.selectedProvider = selectedProvider

        isPresented = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            chatViewModel.sendMessage(prompt)
        }
    }
}
