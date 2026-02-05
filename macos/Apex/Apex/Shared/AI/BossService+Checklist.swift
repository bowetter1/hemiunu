import Foundation

extension BossService {
    // MARK: - Checklist Polling

    /// Start polling `checklist.md` in the workspace for progress updates.
    /// Uses the same pattern as `startChatFilePolling` — Timer on main run loop.
    func startChecklistPolling(workspace: URL) {
        stopChecklistPolling()

        let checklistURL = workspace.appendingPathComponent("checklist.md")

        checklistPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pollChecklist(at: checklistURL)
            }
        }
    }

    /// Parse `checklist.md` and update `checklistProgress`.
    /// Expects lines like `- [x] Step name` and `- [ ] Step name`.
    func pollChecklist(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8),
              !content.isEmpty
        else {
            // No checklist yet — clear progress
            if checklistProgress != nil {
                checklistProgress = nil
            }
            return
        }

        let lines = content.components(separatedBy: .newlines)

        var completed = 0
        var total = 0
        var currentStepName: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                completed += 1
                total += 1
            } else if trimmed.hasPrefix("- [ ]") {
                total += 1
                // First unchecked item is the "current" step
                if currentStepName == nil {
                    let name = trimmed.dropFirst("- [ ]".count)
                        .trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        currentStepName = name
                    }
                }
            }
        }

        guard total > 0 else {
            if checklistProgress != nil {
                checklistProgress = nil
            }
            return
        }

        checklistProgress = ChecklistProgress(
            currentStep: currentStepName,
            completedCount: completed,
            totalCount: total
        )
    }

    /// Stop polling checklist.md.
    func stopChecklistPolling() {
        checklistPollTimer?.invalidate()
        checklistPollTimer = nil
    }
}
