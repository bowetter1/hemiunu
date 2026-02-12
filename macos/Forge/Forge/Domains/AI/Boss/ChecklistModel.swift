import Foundation

/// Status for a checklist item
enum ChecklistStatus: String, Sendable, Codable {
    case pending
    case inProgress = "in_progress"
    case done
    case error
}

/// A single step in the Boss checklist
struct ChecklistItem: Sendable, Identifiable, Codable {
    let id: UUID
    let step: String
    var status: ChecklistStatus

    init(id: UUID = UUID(), step: String, status: ChecklistStatus) {
        self.id = id
        self.step = step
        self.status = status
    }
}

/// Observable model tracking Boss agent progress via a checklist
@MainActor
@Observable
class ChecklistModel {
    var items: [ChecklistItem] = []
    var onChange: (() -> Void)?

    var isActive: Bool { !items.isEmpty }

    var completedCount: Int {
        items.filter { $0.status == .done }.count
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
    }

    var currentStep: String? {
        items.first(where: { $0.status == .inProgress })?.step
    }

    func update(_ newItems: [ChecklistItem]) {
        items = newItems
        onChange?()
    }

    func reset() {
        items = []
        onChange?()
    }
}
