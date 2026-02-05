import SwiftUI

struct CollapsedToolButton: View {
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
