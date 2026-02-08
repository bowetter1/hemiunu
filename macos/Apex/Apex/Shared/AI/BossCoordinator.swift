import SwiftUI
import Observation

/// Manages 1-3 BossInstances. Owns workspace creation, template copying, memory persistence.
/// Supports two-phase flow: research (Claude) → parallel build (all agents).
@MainActor
@Observable
class BossCoordinator {

    // MARK: - Types

    enum BossPhase {
        case idle
        case researching
        case building
    }

    enum WorkspaceRole {
        case solo
        case research
        case researchDesign
        case builder
    }

    // MARK: - State

    var isActive = false
    var bosses: [BossInstance] = []
    var selectedBossId: String?
    var researchBoss: BossInstance?
    var phase: BossPhase = .idle

    /// Whether we already linked the workspace as a local project
    var projectLinked = false

    /// Bosses that have been linked as local projects (tracks per-boss to allow incremental linking)
    var linkedBossIds: Set<String> = []

    /// Build-phase config (stored on first message, used when builders start + checklist generation)
    var buildConfig = GenerationConfig()
    var imageInstruction: String?
    var pendingInspirationImage: NSImage?
    var projectDisplayName: String?
    var sessionName: String?

    weak var delegate: BossCoordinatorDelegate?

    init(delegate: BossCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Computed

    /// The currently selected boss (or first if none selected)
    var selectedBoss: BossInstance? {
        if let id = selectedBossId {
            if let research = researchBoss, research.id == id {
                return research
            }
            return bosses.first { $0.id == id }
        }
        return bosses.first
    }

    /// Messages for the selected boss
    var messages: [ChatMessage] {
        selectedBoss?.messages ?? []
    }

    /// Workspace files for the selected boss
    var workspaceFiles: [LocalFileInfo] {
        selectedBoss?.workspaceFiles ?? []
    }

    /// Workspace URL for the selected boss
    var workspace: URL? {
        selectedBoss?.workspace
    }

    /// Whether any boss is currently processing
    var isProcessing: Bool {
        let builderProcessing = bosses.contains { $0.service.isProcessing }
        let researchProcessing = researchBoss?.service.isProcessing ?? false
        return builderProcessing || researchProcessing
    }

    /// Whether we have multiple bosses running (two-phase mode)
    var isMultiBoss: Bool {
        researchBoss != nil || bosses.count > 1
    }

    // MARK: - Activity

    /// Friendly name of the tool currently being used by the selected boss
    var currentActivityLabel: String? {
        guard let toolName = selectedBoss?.service.currentToolName else { return nil }
        return ToolNameMapper.friendlyName(for: toolName)
    }

    /// Aggregated checklist progress across all builders, or single boss progress
    var aggregatedChecklist: ChecklistProgress? {
        if bosses.count <= 1 {
            return selectedBoss?.service.checklistProgress
        }
        // Multi-boss: sum all builder checklists
        var totalCompleted = 0
        var totalSteps = 0
        var currentStep: String?
        for boss in bosses {
            if let cp = boss.service.checklistProgress {
                totalCompleted += cp.completedCount
                totalSteps += cp.totalCount
                if currentStep == nil, let step = cp.currentStep {
                    currentStep = step
                }
            }
        }
        guard totalSteps > 0 else { return nil }
        return ChecklistProgress(
            currentStep: currentStep,
            completedCount: totalCompleted,
            totalCount: totalSteps
        )
    }

    /// Stats from the most recent completed turn of the selected boss
    var lastStats: TurnStats? {
        selectedBoss?.service.lastTurnStats
    }

}
