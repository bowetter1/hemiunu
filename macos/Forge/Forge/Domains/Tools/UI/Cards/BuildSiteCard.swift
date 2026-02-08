import SwiftUI

// MARK: - Build Site Card

struct BuildSiteCard: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple)
                    .frame(width: 32)

                Text("Build Site")
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
        .disabled(appState.currentProject == nil)
        .opacity(appState.currentProject == nil ? 0.4 : 1)
        .sheet(isPresented: $showSheet) {
            BuildSiteSheet(isPresented: $showSheet, appState: appState, chatViewModel: chatViewModel)
        }
    }
}
