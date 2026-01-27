import SwiftUI

// MARK: - Deploy Tool Card

struct DeployToolCard: View {
    @State private var isExpanded = false
    @State private var autoDeploy = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .frame(width: 28, height: 28)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)

                    Text("Deploy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Current deployment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Production")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("apex-demo.vercel.app")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }

                        Text("Updated 2h ago")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Deploy Now")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Auto-deploy toggle
                    Toggle(isOn: $autoDeploy) {
                        Text("Auto-deploy on push")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}
