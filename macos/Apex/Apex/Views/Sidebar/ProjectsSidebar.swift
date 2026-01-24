import SwiftUI

struct ProjectsSidebar: View {
    @ObservedObject var client: ApexClient
    @Binding var selectedProjectId: String?
    let onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Projects")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onNewProject) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Project")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Project list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(client.projects) { project in
                        ProjectRow(
                            project: project,
                            isSelected: selectedProjectId == project.id
                        ) {
                            selectedProjectId = project.id
                        }
                    }
                }
                .padding(8)
            }

            Spacer()

            // New project button at bottom
            Button(action: onNewProject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("New Project")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.1))
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    // Brief (truncated)
                    Text(projectTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Date + status
                    HStack(spacing: 4) {
                        Text(formattedDate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text(statusText)
                            .font(.system(size: 10))
                            .foregroundColor(statusColor)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    var projectTitle: String {
        // Extract first few words from brief
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    var formattedDate: String {
        // Parse ISO date and format nicely
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: project.createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return ""
    }

    var statusColor: Color {
        switch project.status {
        case .brief, .moodboard, .layouts:
            return .orange
        case .editing, .done:
            return .green
        case .failed:
            return .red
        }
    }

    var statusText: String {
        switch project.status {
        case .brief: return "Starting"
        case .moodboard: return "Moodboard"
        case .layouts: return "Layouts"
        case .editing: return "Editing"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }
}

#Preview {
    ProjectsSidebar(
        client: ApexClient(),
        selectedProjectId: .constant(nil),
        onNewProject: {}
    )
}
