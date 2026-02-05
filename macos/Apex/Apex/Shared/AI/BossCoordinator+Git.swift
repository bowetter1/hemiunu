import SwiftUI

extension BossCoordinator {
    // MARK: - Git

    func initGitRepo(at workspace: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = workspace
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        // Set local git config (ensures commits work without global config)
        let configName = Process()
        configName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configName.arguments = ["config", "user.name", "Apex"]
        configName.currentDirectoryURL = workspace
        configName.standardOutput = FileHandle.nullDevice
        configName.standardError = FileHandle.nullDevice
        try? configName.run()
        configName.waitUntilExit()

        let configEmail = Process()
        configEmail.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configEmail.arguments = ["config", "user.email", "apex@local"]
        configEmail.currentDirectoryURL = workspace
        configEmail.standardOutput = FileHandle.nullDevice
        configEmail.standardError = FileHandle.nullDevice
        try? configEmail.run()
        configEmail.waitUntilExit()
    }

    /// Create an initial commit so every workspace has at least v1
    func initialCommit(at workspace: URL) {
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "-A"]
        addProcess.currentDirectoryURL = workspace
        addProcess.standardOutput = FileHandle.nullDevice
        addProcess.standardError = FileHandle.nullDevice
        try? addProcess.run()
        addProcess.waitUntilExit()

        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", "Setup workspace"]
        commitProcess.currentDirectoryURL = workspace
        commitProcess.standardOutput = FileHandle.nullDevice
        commitProcess.standardError = FileHandle.nullDevice
        try? commitProcess.run()
        commitProcess.waitUntilExit()
    }

}
