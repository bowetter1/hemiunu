import SwiftUI

/// Compact activity log showing Boss + sub-agent events in real time
struct ActivityLogView: View {
    let log: ActivityLog

    var body: some View {
        if log.isActive {
            // Log entries (auto-scrolling)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(log.entries) { entry in
                            entryRow(entry)
                                .id(entry.id)
                        }
                    }
                }
                .frame(maxHeight: 160)
                .onChange(of: log.entries.count) { _, _ in
                    if let last = log.entries.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: ActivityEntry) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text(entry.icon)
                .font(.system(size: 10))
                .frame(width: 12, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(log.relativeTime(entry))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    if let role = entry.role {
                        Text(role)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(entry.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(3)
            }
        }
    }
}
