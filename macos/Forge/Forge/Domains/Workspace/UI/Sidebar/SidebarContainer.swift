import SwiftUI
import AppKit

/// Left sidebar — project navigation and file listing
struct SidebarContainer: View {
    var appState: AppState
    let currentMode: AppMode
    @Binding var selectedProjectId: String?
    @Binding var selectedPageId: String?
    @Binding var showResearchJSON: Bool
    let onNewProject: () -> Void
    let onClose: () -> Void
    @State private var sidebarWidth: CGFloat = 200
    @GestureState private var dragOffset: CGFloat = 0

    private let minWidth: CGFloat = 160
    private let maxWidth: CGFloat = 900

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Explorer")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onClose() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().opacity(0.5)

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
        .frame(width: max(minWidth, min(maxWidth, sidebarWidth + dragOffset)))
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .trailing) { resizeHandle }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        sidebarWidth = max(minWidth, min(maxWidth, sidebarWidth + value.translation.width))
                    }
            )
    }
}
