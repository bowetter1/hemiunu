import Foundation

/// A single entry in the Boss activity log
struct ActivityEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp = Date()
    let icon: String
    let message: String
    let role: String? // nil = boss-level, "researcher"/"coder" = sub-agent
}

/// Observable model tracking all Boss activity — tool calls, sub-agent events, status changes
@MainActor
@Observable
class ActivityLog {
    var entries: [ActivityEntry] = []
    private var startTime: Date?

    var isActive: Bool { !entries.isEmpty }

    /// Elapsed seconds since first entry
    var elapsed: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func append(_ icon: String, _ message: String, role: String? = nil) {
        if startTime == nil { startTime = Date() }
        entries.append(ActivityEntry(icon: icon, message: message, role: role))
    }

    func reset() {
        entries = []
        startTime = nil
    }

    /// Formatted elapsed time for an entry relative to start
    func relativeTime(_ entry: ActivityEntry) -> String {
        guard let start = startTime else { return "0:00" }
        let seconds = Int(entry.timestamp.timeIntervalSince(start))
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
