import Foundation

extension BossToolExecutor {
    // MARK: - Update Checklist

    func executeUpdateChecklist(_ call: ToolCall) -> String {
        let args = parseArguments(call.arguments)
        guard let itemsArray = args["items"] as? [[String: Any]] else {
            return "Error: missing items array"
        }

        let items: [ChecklistItem] = itemsArray.compactMap { dict in
            guard let step = dict["step"] as? String,
                  let statusString = dict["status"] as? String,
                  let status = ChecklistStatus(rawValue: statusString) else {
                return nil
            }
            return ChecklistItem(step: step, status: status)
        }

        onChecklistUpdate(items)

        // Also write checklist.md to workspace for persistence.
        let markdown = items.map { item in
            let icon: String
            switch item.status {
            case .pending: icon = "⬜"
            case .inProgress: icon = "🔄"
            case .done: icon = "✅"
            case .error: icon = "❌"
            }
            return "\(icon) \(item.step)"
        }.joined(separator: "\n")

        try? workspace.writeFile(project: projectName, path: "checklist.md", content: "# Task Checklist\n\n\(markdown)\n")

        return "Checklist updated: \(items.count) items"
    }
}
