import SwiftUI

/// Left sidebar — project navigation and file listing
/// Rendered inside NavigationSplitView sidebar column (automatic Liquid Glass)
struct SidebarContainer: View {
    @ObservedObject var appState: AppState
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    var onNewProject: () -> Void

    var body: some View {
        // File listing (mode-aware)
        FilesTabContent(
            appState: appState,
            currentMode: currentMode,
            selectedProjectId: $selectedProjectId,
            selectedPageId: $selectedPageId,
            showResearchJSON: $showResearchJSON,
            onNewProject: onNewProject
        )
        .navigationTitle("Explorer")
        .toolbar(removing: .sidebarToggle)
    }
}
