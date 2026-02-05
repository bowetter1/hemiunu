import SwiftUI

// MARK: - Database Tool Card

struct DatabaseToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "cylinder")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                        .frame(width: 28, height: 28)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(6)

                    Text("Database")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    // Connected indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
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
                    // Provider
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Supabase Connected")
                            .font(.system(size: 11, weight: .medium))
                    }

                    // Tables list
                    VStack(alignment: .leading, spacing: 4) {
                        DatabaseTableRow(name: "users", rows: 124)
                        DatabaseTableRow(name: "posts", rows: 56)
                        DatabaseTableRow(name: "comments", rows: 892)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9))
                                Text("New Table")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
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
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DatabaseTableRow: View {
    let name: String
    let rows: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tablecells")
                .font(.system(size: 9))
                .foregroundColor(.cyan)

            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text("\(rows) rows")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
