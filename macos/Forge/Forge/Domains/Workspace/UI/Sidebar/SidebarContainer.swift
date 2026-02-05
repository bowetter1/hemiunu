import SwiftUI

/// Left sidebar — project navigation and file listing
struct SidebarContainer: View {
    @ObservedObject var appState: AppState
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void
    let onClose: () -> Void

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

            // File listing (mode-aware)
            FilesTabContent(
                appState: appState,
                currentMode: currentMode,
                selectedProjectId: $selectedProjectId,
                selectedPageId: $selectedPageId,
                showResearchJSON: $showResearchJSON,
                onNewProject: onNewProject
            )
        }
        .frame(width: 240)
        .background(Theme.Colors.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }
}
