import Foundation

extension LocalWorkspaceService {
    // MARK: - Full Pipeline

    /// Complete pipeline: search → clone → patch → install → build → deploy
    func runPipeline(
        name: String,
        repoUrl: String,
        branch: String = "main",
        patches: [FilePatch] = [],
        envVars: [String: String] = [:],
        onProgress: @escaping (PipelineStep) -> Void
    ) async throws -> PipelineResult {
        isRunning = true
        defer { isRunning = false }

        var result = PipelineResult()

        // Step 1: Clone
        onProgress(.cloning)
        activeProcess = "Cloning \(repoUrl)..."
        let cloneResult = try await cloneRepo(url: repoUrl, name: name, branch: branch)
        result.cloneOutput = cloneResult.output
        guard cloneResult.exitCode == 0 else {
            throw WorkspaceError.cloneFailed(cloneResult.output)
        }

        // Step 2: Patch
        if !patches.isEmpty {
            onProgress(.patching)
            activeProcess = "Applying \(patches.count) patches..."
            result.patchCount = try applyPatches(project: name, patches: patches)
        }

        // Step 3: Install
        onProgress(.installing)
        activeProcess = "npm install..."
        let installResult = try await npmInstall(project: name)
        result.installOutput = installResult.output
        guard installResult.exitCode == 0 else {
            throw WorkspaceError.installFailed(installResult.output)
        }

        // Step 4: Build
        onProgress(.building)
        activeProcess = "npm run build..."
        let buildResult = try await npmBuild(project: name)
        result.buildOutput = buildResult.output
        guard buildResult.exitCode == 0 else {
            throw WorkspaceError.buildFailed(buildResult.output)
        }

        // Step 5: Deploy (optional)
        if !envVars.isEmpty {
            onProgress(.settingVars)
            activeProcess = "Setting environment variables..."
            _ = try await railwaySetVars(project: name, vars: envVars)
        }

        onProgress(.deploying)
        activeProcess = "Deploying to Railway..."
        let deployResult = try await railwayDeploy(project: name)
        result.deployOutput = deployResult.output

        // Step 6: Get domain
        onProgress(.gettingDomain)
        activeProcess = "Getting domain..."
        let domainResult = try await railwayDomain(project: name)
        result.liveUrl = domainResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        onProgress(.done)
        activeProcess = nil
        return result
    }

}
