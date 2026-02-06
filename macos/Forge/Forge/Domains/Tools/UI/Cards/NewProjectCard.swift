import SwiftUI

// MARK: - New Project Card

struct NewProjectCard: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    let onProjectCreated: (String) -> Void

    @State private var showStartSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showStartSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)

                    Text("New Project")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .sheet(isPresented: $showStartSheet) {
            StartProjectSheet(
                isPresented: $showStartSheet,
                chatViewModel: chatViewModel,
                onProjectCreated: onProjectCreated
            )
        }
    }
}
