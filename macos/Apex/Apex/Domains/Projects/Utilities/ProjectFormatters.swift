import SwiftUI

/// Shared project formatting utilities used across sidebar views
enum ProjectFormatters {
    /// Truncated title from project brief (first 4 words)
    static func projectTitle(_ project: Project) -> String {
        let words = project.brief.split(separator: " ").prefix(4)
        let title = words.joined(separator: " ")
        return title.count < project.brief.count ? "\(title)..." : title
    }

    /// Status color for a project
    static func statusColor(for project: Project) -> Color {
        switch project.status {
        case .editing, .done:
            return .green
        case .failed:
            return .red
        default:
            return .orange
        }
    }

    /// Format ISO8601 date string to "MMM d" display format
    static func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return ""
    }
}
