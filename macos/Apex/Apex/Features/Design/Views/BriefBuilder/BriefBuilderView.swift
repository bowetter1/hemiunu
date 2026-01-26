import SwiftUI

/// Simple welcome view when no project is selected
struct BriefBuilderView: View {
    @ObservedObject var client: APIClient
    let onProjectCreated: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Welcome to Apex")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Build anything. Just describe it.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }


            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    BriefBuilderView(client: APIClient()) { _ in }
        .frame(width: 600, height: 400)
}
