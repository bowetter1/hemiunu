import SwiftUI

/// Compact checklist view showing Boss agent progress
struct ChecklistView: View {
    let checklist: ChecklistModel

    var body: some View {
        if checklist.isActive {
            VStack(alignment: .leading, spacing: 8) {
                // Header with progress
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Progress")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(checklist.completedCount)/\(checklist.items.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                ProgressView(value: checklist.progress)
                    .tint(.orange)

                // Item list
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(checklist.items) { item in
                        HStack(spacing: 6) {
                            statusIcon(item.status)
                                .font(.system(size: 11))
                                .frame(width: 14)
                            Text(item.step)
                                .font(.system(size: 11))
                                .foregroundStyle(item.status == .done ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            .background(.fill.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: ChecklistStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .inProgress:
            ProgressView()
                .controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
