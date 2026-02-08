import SwiftUI

// MARK: - New Project Card

struct NewProjectCard: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    let onProjectCreated: (String) -> Void

    @State private var showStartSheet = false

    var body: some View {
        Button(action: { showStartSheet = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                Text("New Project")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showStartSheet) {
            StartProjectSheet(
                isPresented: $showStartSheet,
                chatViewModel: chatViewModel,
                onProjectCreated: onProjectCreated
            )
        }
    }
}
