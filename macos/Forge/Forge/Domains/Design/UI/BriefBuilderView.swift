import SwiftUI

/// Simple welcome view when no project is selected
struct BriefBuilderView: View {
    var appState: AppState
    let onProjectCreated: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Welcome to Forge")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Build anything. Just describe it.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
