import Foundation
import Observation

/// Local workspace service — runs git, npm, build, deploy directly on the Mac.
/// No Daytona API round-trips. Files live at ~/Apex/projects/<name>/
@MainActor
@Observable
class LocalWorkspaceService {
    static let shared = LocalWorkspaceService()

    /// Root directory for all local projects
    let rootDirectory: URL

    var isRunning = false
    var lastOutput: String = ""
    var activeProcess: String?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        rootDirectory = home.appendingPathComponent("Apex/projects")
        ensureRootExists()
    }

    // MARK: - Directory Management

    /// Ensure ~/Apex/projects/ exists
    private func ensureRootExists() {
        try? FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Get the local path for a project
    func projectPath(_ name: String) -> URL {
        rootDirectory.appendingPathComponent(name)
    }

    /// Check if a project directory exists locally
    func projectExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: projectPath(name).path)
    }

    /// List all local projects
    func listProjects() -> [LocalProject] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else { return nil }

            let hasPackageJson = fm.fileExists(atPath: url.appendingPathComponent("package.json").path)
            let hasGit = fm.fileExists(atPath: url.appendingPathComponent(".git").path)
            let hasDockerfile = fm.fileExists(atPath: url.appendingPathComponent("Dockerfile").path)

            return LocalProject(
                name: url.lastPathComponent,
                path: url,
                modifiedAt: values.contentModificationDate ?? Date.distantPast,
                hasPackageJson: hasPackageJson,
                hasGit: hasGit,
                hasDockerfile: hasDockerfile
            )
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: - Local Preview Server

    private var serverProcess: Process?
    private(set) var serverPort: Int?

    /// Start a local HTTP server for previewing project files
    func startLocalServer(project: String, port: Int = 8421) async throws -> Int {
        stopLocalServer()

        let projectDir = projectPath(project)
        guard FileManager.default.fileExists(atPath: projectDir.path) else {
            throw WorkspaceError.invalidURL
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "http.server", "\(port)", "--bind", "127.0.0.1"]
        process.currentDirectoryURL = projectDir
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        serverProcess = process
        serverPort = port

        // Give the server a moment to start
        try await Task.sleep(nanoseconds: 500_000_000)
        return port
    }

    /// Stop the local preview server
    func stopLocalServer() {
        serverProcess?.terminate()
        serverProcess = nil
        serverPort = nil
    }

    /// List workspace directories that contain HTML files (includes nested session/boss dirs)
    func listHTMLWorkspaces() -> [LocalProject] {
        let fm = FileManager.default
        var workspaces: [LocalProject] = []

        guard let topDirs = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for dir in topDirs {
            guard let values = try? dir.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else { continue }

            let topName = dir.lastPathComponent

            // Check top-level dir for HTML
            if findMainHTML(project: topName) != nil {
                workspaces.append(LocalProject(
                    name: topName,
                    path: dir,
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    hasPackageJson: fm.fileExists(atPath: dir.appendingPathComponent("package.json").path),
                    hasGit: fm.fileExists(atPath: dir.appendingPathComponent(".git").path),
                    hasDockerfile: fm.fileExists(atPath: dir.appendingPathComponent("Dockerfile").path),
                    briefTitle: readBriefTitle(at: dir)
                ))
            }

            // Check subdirectories (session-XXX/boss-0, session-XXX/boss-1, etc.)
            guard let subDirs = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for sub in subDirs {
                guard let subValues = try? sub.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                      subValues.isDirectory == true else { continue }

                let relativeName = "\(topName)/\(sub.lastPathComponent)"
                if findMainHTML(project: relativeName) != nil {
                    let agentName = try? String(
                        contentsOf: sub.appendingPathComponent("agent-name.txt"),
                        encoding: .utf8
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    workspaces.append(LocalProject(
                        name: relativeName,
                        path: sub,
                        modifiedAt: subValues.contentModificationDate ?? .distantPast,
                        hasPackageJson: fm.fileExists(atPath: sub.appendingPathComponent("package.json").path),
                        hasGit: fm.fileExists(atPath: sub.appendingPathComponent(".git").path),
                        hasDockerfile: fm.fileExists(atPath: sub.appendingPathComponent("Dockerfile").path),
                        briefTitle: readBriefTitle(at: sub),
                        agentName: agentName
                    ))
                }
            }
        }

        return workspaces.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Read project name — checks project-name.txt (in workspace or parent), then falls back to brief.md
    private func readBriefTitle(at url: URL) -> String? {
        // Check project-name.txt in this directory
        let nameFile = url.appendingPathComponent("project-name.txt")
        if let name = try? String(contentsOf: nameFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        // Check project-name.txt in parent directory (session level)
        let parentNameFile = url.deletingLastPathComponent().appendingPathComponent("project-name.txt")
        if let name = try? String(contentsOf: parentNameFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        // Fall back to parsing brief.md
        let briefURL = url.appendingPathComponent("brief.md")
        guard let content = try? String(contentsOf: briefURL, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        var foundProject = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("## project") {
                foundProject = true
                continue
            }
            if foundProject && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let clean = trimmed
                    .components(separatedBy: "—").first?
                    .components(separatedBy: ".").first?
                    .trimmingCharacters(in: .whitespaces) ?? trimmed
                if clean.count > 35 {
                    return String(clean.prefix(32)) + "..."
                }
                return clean.isEmpty ? nil : clean
            }
        }
        return nil
    }

    /// Find the main HTML file in a project (index.html or similar)
    func findMainHTML(project: String) -> String? {
        let dir = projectPath(project)
        let candidates = [
            "index.html",
            "proposal/index.html",
            "dist/index.html",
            "build/index.html",
            "public/index.html",
            "out/index.html",
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
                return candidate
            }
        }
        // Fallback: find any .html file at root
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.first { $0.hasSuffix(".html") }
    }

    /// Read HTML content from a local project's main file
    func readMainHTML(project: String) -> String? {
        guard let htmlFile = findMainHTML(project: project) else { return nil }
        let filePath = projectPath(project).appendingPathComponent(htmlFile)
        return try? String(contentsOf: filePath, encoding: .utf8)
    }

    // MARK: - Workspace Cleanup

    /// Remove old workspace directories older than the given interval
    func cleanOldWorkspaces(olderThan interval: TimeInterval = 7 * 24 * 3600) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-interval)
        for url in contents {
            let name = url.lastPathComponent
            guard (name.hasPrefix("session-") || name.hasPrefix("boss-") || name.hasPrefix("solo-")),
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }

            // Only remove if the directory is empty or has no meaningful files
            let files = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            let meaningfulFiles = files.filter { !$0.hasPrefix(".") }
            if meaningfulFiles.isEmpty {
                try? fm.removeItem(at: url)
            }
        }
    }

    // MARK: - Git Operations

    /// Clone a GitHub repo into ~/Apex/projects/<name>/
    func cloneRepo(url: String, name: String, branch: String = "main") async throws -> ShellResult {
        let dest = projectPath(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        return try await exec("git clone --branch \(branch) --single-branch \(url) \(dest.path)")
    }

    /// Git status for a project
    func gitStatus(project: String) async throws -> ShellResult {
        try await exec("git status", cwd: projectPath(project))
    }

    /// Git commit all changes
    func gitCommit(project: String, message: String) async throws -> ShellResult {
        let dir = projectPath(project)
        _ = try await exec("git add -A", cwd: dir)
        return try await exec("git commit -m \"\(message)\" --allow-empty-message", cwd: dir)
    }

    /// Git log — returns commits as PageVersion objects (oldest first, version 1-based)
    func gitVersions(project: String) async throws -> [PageVersion] {
        let dir = projectPath(project)
        let result = try await exec("git log --format=%H||%s||%aI --reverse", cwd: dir)
        guard result.succeeded else { return [] }

        return result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, line in
                let parts = line.components(separatedBy: "||")
                guard parts.count >= 3, !parts[0].isEmpty else { return nil }
                return PageVersion(
                    id: parts[0],
                    version: index + 1,
                    instruction: parts[1].isEmpty ? nil : parts[1],
                    createdAt: parts[2]
                )
            }
    }

    /// Restore workspace files to a specific git commit
    func gitRestore(project: String, commitHash: String) async throws {
        let dir = projectPath(project)
        _ = try await exec("git checkout \(commitHash) -- .", cwd: dir)
    }

    // MARK: - File Operations

    /// Read a file from a local project
    func readFile(project: String, path: String) throws -> String {
        let filePath = projectPath(project).appendingPathComponent(path)
        return try String(contentsOf: filePath, encoding: .utf8)
    }

    /// Write a file to a local project
    func writeFile(project: String, path: String, content: String) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Write binary data to a local project
    func writeBinary(project: String, path: String, data: Data) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        let dir = filePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: filePath)
    }

    /// Delete a file from a local project
    func deleteFile(project: String, path: String) throws {
        let filePath = projectPath(project).appendingPathComponent(path)
        try FileManager.default.removeItem(at: filePath)
    }

    /// List files in a project directory (recursive)
    func listFiles(project: String, directory: String = "") -> [LocalFileInfo] {
        let dir = directory.isEmpty
            ? projectPath(project)
            : projectPath(project).appendingPathComponent(directory)

        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [LocalFileInfo] = []
        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let relativePath = url.path.replacingOccurrences(
                of: projectPath(project).path + "/",
                with: ""
            )
            // Skip node_modules and .next
            if relativePath.hasPrefix("node_modules") || relativePath.hasPrefix(".next") {
                enumerator.skipDescendants()
                continue
            }
            files.append(LocalFileInfo(
                path: relativePath,
                isDirectory: values?.isDirectory ?? false,
                size: values?.fileSize ?? 0
            ))
        }
        return files
    }

    // MARK: - Build Operations

    /// npm install in a project
    func npmInstall(project: String, flags: String = "--legacy-peer-deps") async throws -> ShellResult {
        try await exec("npm install \(flags)", cwd: projectPath(project))
    }

    /// npm run build
    func npmBuild(project: String, maxMemory: Int = 4096) async throws -> ShellResult {
        try await exec(
            "NODE_OPTIONS='--max-old-space-size=\(maxMemory)' npm run build",
            cwd: projectPath(project),
            timeout: 300
        )
    }

    /// npm run dev (returns immediately, server runs in background)
    func npmDev(project: String, port: Int = 3000) async throws -> ShellResult {
        try await exec(
            "PORT=\(port) npm run dev &",
            cwd: projectPath(project),
            timeout: 5
        )
    }

    // MARK: - Deploy Operations

    /// Deploy to Railway
    func railwayDeploy(project: String, detach: Bool = true) async throws -> ShellResult {
        try await exec(
            "railway up\(detach ? " --detach" : "")",
            cwd: projectPath(project),
            timeout: 600
        )
    }

    /// Set Railway environment variables
    func railwaySetVars(project: String, vars: [String: String]) async throws -> ShellResult {
        let pairs = vars.map { "\($0.key)=\($0.value)" }.joined(separator: "\" --set \"")
        return try await exec(
            "railway variables --set \"\(pairs)\" --skip-deploys",
            cwd: projectPath(project)
        )
    }

    /// Get Railway domain
    func railwayDomain(project: String) async throws -> ShellResult {
        try await exec("railway domain", cwd: projectPath(project))
    }

    // MARK: - Patch Operations

    /// Apply sed-style text replacement in a file
    func patchFile(project: String, path: String, find: String, replace: String) throws {
        let content = try readFile(project: project, path: path)
        let patched = content.replacingOccurrences(of: find, with: replace)
        try writeFile(project: project, path: path, content: patched)
    }

    /// Apply multiple patches to a project
    func applyPatches(project: String, patches: [FilePatch]) throws -> Int {
        var count = 0
        for patch in patches {
            switch patch.operation {
            case .replace(let find, let replaceWith):
                try patchFile(project: project, path: patch.path, find: find, replace: replaceWith)
                count += 1
            case .write(let content):
                try writeFile(project: project, path: patch.path, content: content)
                count += 1
            case .delete:
                try deleteFile(project: project, path: patch.path)
                count += 1
            }
        }
        return count
    }

    // MARK: - GitHub Search

    /// Search GitHub for template repos
    func searchGitHub(query: String, sort: String = "stars", perPage: Int = 5) async throws -> [GitHubRepo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.github.com/search/repositories?q=\(encoded)&sort=\(sort)&per_page=\(perPage)"
        guard let url = URL(string: urlString) else { throw WorkspaceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WorkspaceError.githubSearchFailed
        }

        let result = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)
        return result.items.map { item in
            GitHubRepo(
                fullName: item.full_name,
                description: item.description ?? "",
                stars: item.stargazers_count,
                url: item.html_url,
                cloneUrl: item.clone_url,
                updatedAt: item.updated_at,
                language: item.language ?? "Unknown",
                license: item.license?.spdx_id
            )
        }
    }

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

    // MARK: - Shell Execution

    /// Run a shell command and return result
    func exec(
        _ command: String,
        cwd: URL? = nil,
        timeout: TimeInterval = 120,
        env: [String: String]? = nil
    ) async throws -> ShellResult {
        let result: ShellResult = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = pipe
                process.standardError = pipe

                if let cwd = cwd {
                    process.currentDirectoryURL = cwd
                }

                // Inherit user PATH + add common tool locations
                var environment = ProcessInfo.processInfo.environment
                let extraPaths = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "/usr/local/share/npm/bin",
                    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/v20/bin",
                    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.railway/bin",
                ]
                let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
                environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")

                if let env = env {
                    for (key, value) in env {
                        environment[key] = value
                    }
                }
                process.environment = environment

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: WorkspaceError.processLaunchFailed(error.localizedDescription))
                    return
                }

                // Timeout
                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )

                process.waitUntilExit()
                timeoutWorkItem.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                continuation.resume(returning: ShellResult(
                    exitCode: Int(process.terminationStatus),
                    output: output
                ))
            }
        }
        lastOutput = result.output
        return result
    }
}

// MARK: - Data Types

struct LocalProject: Identifiable {
    let name: String
    let path: URL
    let modifiedAt: Date
    let hasPackageJson: Bool
    let hasGit: Bool
    let hasDockerfile: Bool
    var briefTitle: String? = nil
    var agentName: String? = nil

    var id: String { name }
}

struct LocalProjectGroup: Identifiable {
    let sessionName: String
    let projects: [LocalProject]

    var id: String { sessionName }

    var displayName: String {
        if let title = projects.first?.briefTitle {
            return title
        }
        return dateLabel
    }

    var hasBriefTitle: Bool {
        projects.first?.briefTitle != nil
    }

    var dateLabel: String {
        guard sessionName.hasPrefix("session-") else { return sessionName }
        let datePart = String(sessionName.dropFirst("session-".count))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        guard let date = formatter.date(from: datePart) else { return sessionName }
        let display = DateFormatter()
        display.dateFormat = "MMM d, HH:mm"
        return display.string(from: date)
    }

    var latestModified: Date {
        projects.map(\.modifiedAt).max() ?? .distantPast
    }

    static func group(_ projects: [LocalProject]) -> [LocalProjectGroup] {
        var sessionMap: [String: [LocalProject]] = [:]
        var standalone: [LocalProject] = []

        for project in projects {
            let parts = project.name.components(separatedBy: "/")
            if parts.count == 2 {
                sessionMap[parts[0], default: []].append(project)
            } else {
                standalone.append(project)
            }
        }

        var groups: [LocalProjectGroup] = []
        for (session, members) in sessionMap {
            groups.append(LocalProjectGroup(
                sessionName: session,
                projects: members.sorted { $0.name < $1.name }
            ))
        }
        for project in standalone {
            groups.append(LocalProjectGroup(
                sessionName: project.name,
                projects: [project]
            ))
        }

        return groups.sorted { $0.latestModified > $1.latestModified }
    }
}

struct LocalFileInfo: Identifiable {
    let path: String
    let isDirectory: Bool
    let size: Int

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}

struct ShellResult {
    let exitCode: Int
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

struct FilePatch {
    let path: String
    let operation: PatchOperation

    enum PatchOperation {
        case replace(find: String, with: String)
        case write(content: String)
        case delete
    }
}

struct GitHubRepo: Identifiable {
    let fullName: String
    let description: String
    let stars: Int
    let url: String
    let cloneUrl: String
    let updatedAt: String
    let language: String
    let license: String?

    var id: String { fullName }
}

struct PipelineResult {
    var cloneOutput: String = ""
    var patchCount: Int = 0
    var installOutput: String = ""
    var buildOutput: String = ""
    var deployOutput: String = ""
    var liveUrl: String = ""
}

enum PipelineStep: String {
    case cloning = "Cloning repository..."
    case patching = "Applying patches..."
    case installing = "Installing dependencies..."
    case building = "Building project..."
    case settingVars = "Setting environment variables..."
    case deploying = "Deploying to Railway..."
    case gettingDomain = "Getting live URL..."
    case done = "Done!"
}

enum WorkspaceError: LocalizedError {
    case invalidURL
    case githubSearchFailed
    case cloneFailed(String)
    case installFailed(String)
    case buildFailed(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .githubSearchFailed: return "GitHub search failed"
        case .cloneFailed(let output): return "Clone failed: \(output)"
        case .installFailed(let output): return "Install failed: \(output)"
        case .buildFailed(let output): return "Build failed: \(output)"
        case .processLaunchFailed(let msg): return "Process launch failed: \(msg)"
        }
    }
}

// MARK: - GitHub API Types (private)

private struct GitHubSearchResponse: Codable {
    let items: [GitHubRepoItem]
}

private struct GitHubRepoItem: Codable {
    let full_name: String
    let description: String?
    let stargazers_count: Int
    let html_url: String
    let clone_url: String
    let updated_at: String
    let language: String?
    let license: GitHubLicense?
}

private struct GitHubLicense: Codable {
    let spdx_id: String?
}
