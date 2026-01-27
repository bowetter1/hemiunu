import SwiftUI

// MARK: - Git Tool Card

struct GitToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)

                    Text("Git")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Changes badge
                    Text("3")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(8)

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
                    // Branch selector
                    HStack {
                        Text("Branch:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text("main")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // Changes list
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uncommitted changes")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        FileChangeRow(filename: "index.html", status: "M")
                        FileChangeRow(filename: "about.html", status: "M")
                        FileChangeRow(filename: "styles.css", status: "A")
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Commit")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Text("Push")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct FileChangeRow: View {
    let filename: String
    let status: String

    var statusColor: Color {
        switch status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(status)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor)
                .frame(width: 14)

            Text(filename)
                .font(.system(size: 10))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
