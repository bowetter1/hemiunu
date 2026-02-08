import SwiftUI

// MARK: - Opus Design Card

struct OpusDesignCard: View {
    @ObservedObject var appState: AppState
    var chatViewModel: ChatViewModel
    let onProjectCreated: (String) -> Void

    @State private var showSheet = false

    private var isAvailable: Bool {
        BossService.isAvailable(agent: .claude) && BossService.isAvailable(agent: .kimi)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .frame(width: 28, height: 28)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)

                    Text("Opus Design")
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
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.5)
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .sheet(isPresented: $showSheet) {
            OpusDesignSheet(
                isPresented: $showSheet,
                boss: chatViewModel.boss,
                onProjectCreated: onProjectCreated
            )
        }
    }
}
