import SwiftUI

/// Unified sidebar showing files, components and assets
struct UnifiedSidebar: View {
    @ObservedObject var appState: AppState
    private var client: APIClient { appState.client }
    @ObservedObject var webSocket: WebSocketManager
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedVariantId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
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
                            appState: appState,
                            currentMode: currentMode,
                            selectedProjectId: $selectedProjectId,
                            selectedVariantId: $selectedVariantId,
                            selectedPageId: $selectedPageId,
                            showResearchJSON: $showResearchJSON,
                            onNewProject: onNewProject
                        )
                    }

                    // Research section - click to show JSON in main area
                    if appState.currentProject?.moodboard != nil {
                        Button(action: {
                            selectedPageId = nil
                            showResearchJSON = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundColor(showResearchJSON ? .blue : .secondary)
                                    .frame(width: 16)

                                Text("Research Data")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("JSON")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(showResearchJSON ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
