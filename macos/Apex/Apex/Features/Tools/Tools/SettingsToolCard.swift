import SwiftUI

// MARK: - Settings Tool Card

struct SettingsToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)

                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    SettingsRow(icon: "globe", title: "Domain", subtitle: "mysite.com")
                    SettingsRow(icon: "key", title: "Environment", subtitle: "3 variables")
                    SettingsRow(icon: "link", title: "Integrations", subtitle: "Supabase, Stripe")
                    SettingsRow(icon: "square.and.arrow.up", title: "Export", subtitle: "Download project")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
