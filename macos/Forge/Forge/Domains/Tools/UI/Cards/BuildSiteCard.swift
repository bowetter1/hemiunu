import SwiftUI

// MARK: - Build Site Card

struct BuildSiteCard: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .frame(width: 28, height: 28)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(6)

                Text("Build Site")
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
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .disabled(appState.currentProject == nil)
        .opacity(appState.currentProject == nil ? 0.4 : 1)
        .sheet(isPresented: $showSheet) {
            BuildSiteSheet(isPresented: $showSheet, appState: appState, chatViewModel: chatViewModel)
        }
    }
}
