import SwiftUI
import UniformTypeIdentifiers

// MARK: - New Project Card

struct NewProjectCard: View {
    @ObservedObject var appState: AppState
    private var client: APIClient { appState.client }
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
                let project = try await client.projectService.create(brief: enhancedBrief)
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
