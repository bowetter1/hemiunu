import SwiftUI

// MARK: - Component Row (Mockup)

struct ComponentRow: View {
    let name: String
    let icon: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Asset Row (Mockup)

struct AssetRow: View {
    let name: String
    let icon: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
