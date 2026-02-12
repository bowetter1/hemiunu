import Foundation

/// A single entry in the Boss activity log
struct ActivityEntry: Identifiable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let icon: String
    let message: String
    let role: String? // nil = boss-level, "researcher"/"coder" = sub-agent

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        icon: String,
        message: String,
        role: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.icon = icon
        self.message = message
        self.role = role
    }
}

struct PersistedActivityLog: Codable {
    let entries: [ActivityEntry]
    let startTime: Date?
}

/// Observable model tracking all Boss activity — tool calls, sub-agent events, status changes
@MainActor
@Observable
class ActivityLog {
    var entries: [ActivityEntry] = []
    private var startTime: Date?
    var onChange: (() -> Void)?

    var isActive: Bool { !entries.isEmpty }

    /// Elapsed seconds since first entry
    var elapsed: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func append(_ icon: String, _ message: String, role: String? = nil) {
        if startTime == nil { startTime = Date() }
        entries.append(ActivityEntry(icon: icon, message: message, role: role))
        onChange?()
    }

    func reset() {
        entries = []
        startTime = nil
        onChange?()
    }

    /// Formatted elapsed time for an entry relative to start
    func relativeTime(_ entry: ActivityEntry) -> String {
        guard let start = startTime else { return "0:00" }
        let seconds = Int(entry.timestamp.timeIntervalSince(start))
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func snapshot() -> PersistedActivityLog {
        PersistedActivityLog(entries: entries, startTime: startTime)
    }

    func restore(from snapshot: PersistedActivityLog) {
        entries = snapshot.entries
        if let start = snapshot.startTime {
            startTime = start
        } else {
            startTime = snapshot.entries.first?.timestamp
        }
        onChange?()
    }
}
