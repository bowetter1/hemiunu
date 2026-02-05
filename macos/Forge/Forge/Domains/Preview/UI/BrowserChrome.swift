import SwiftUI

/// Lightweight browser chrome wrapper for previews
struct BrowserChrome<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Circle().fill(Color.yellow).frame(width: 8, height: 8)
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Spacer()
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
