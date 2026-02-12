import Foundation

/// Executes Boss-level tool calls: delegates to sub-agents, updates checklist, or falls through to standard tools
@MainActor
class BossToolExecutor: ToolExecuting {
    let workspace: LocalWorkspaceService
    var projectName: String
    let serviceResolver: (AIProvider) -> any AIService
    let builderServiceResolver: ((String) -> any AIService)?
    let onChecklistUpdate: ([ChecklistItem]) -> Void
    let onSubAgentEvent: (String, AgentEvent) -> Void
    let onProjectCreate: ((String) -> Void)?
    let onFileWrite: (() -> Void)?
    let onBuilderDone: ((String) -> Void)?
    var buildLogger: BuildLogger?
    var memoryService: MemoryService?

    init(
        workspace: LocalWorkspaceService,
        projectName: String,
        serviceResolver: @escaping (AIProvider) -> any AIService,
        builderServiceResolver: ((String) -> any AIService)? = nil,
        onChecklistUpdate: @escaping ([ChecklistItem]) -> Void,
        onSubAgentEvent: @escaping (String, AgentEvent) -> Void,
        onProjectCreate: ((String) -> Void)? = nil,
        onFileWrite: (() -> Void)? = nil,
        onBuilderDone: ((String) -> Void)? = nil
    ) {
        self.workspace = workspace
        self.projectName = projectName
        self.serviceResolver = serviceResolver
        self.builderServiceResolver = builderServiceResolver
        self.onChecklistUpdate = onChecklistUpdate
        self.onSubAgentEvent = onSubAgentEvent
        self.onProjectCreate = onProjectCreate
        self.onFileWrite = onFileWrite
        self.onBuilderDone = onBuilderDone
    }

    var priorityToolNames: Set<String> { ["create_project"] }

    /// Inner executor for standard file/search tools
    private var standardExecutor: ToolExecutor {
        ToolExecutor(workspace: workspace, projectName: projectName, onFileWrite: onFileWrite)
    }

    func execute(_ call: ToolCall) async throws -> String {
        switch call.name {
        case "create_project":
            return executeCreateProject(call)
        case "delegate_task":
            return try await executeDelegateTask(call)
        case "build_version":
            return try await executeBuildVersion(call)
        case "update_checklist":
            return executeUpdateChecklist(call)
        default:
            return try await standardExecutor.execute(call)
        }
    }
}
