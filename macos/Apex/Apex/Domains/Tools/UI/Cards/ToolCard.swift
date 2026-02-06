import SwiftUI

// MARK: - Tool Card

struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(disabled ? .secondary : color)
                    .frame(width: 28, height: 28)
                    .background((disabled ? Color.secondary : color).opacity(0.15))
                    .cornerRadius(6)

                Text(title)
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
        .disabled(disabled)
        .background(isHovering && !disabled ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .opacity(disabled ? 0.5 : 1)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

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
