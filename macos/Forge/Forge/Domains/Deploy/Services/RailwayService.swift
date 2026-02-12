import Foundation

/// CLI wrapper for Railway deploy operations.
/// Railway CLI must be installed (`brew install railway`) and authenticated (`railway login`).
enum RailwayService {

    // MARK: - Availability

    /// Check if Railway CLI is installed
    static var isAvailable: Bool {
        let result = runCLISync("which railway")
        return result?.exitCode == 0
    }

    // MARK: - Project Lifecycle

    /// Create a Railway project in the given directory
    static func createProject(name: String, cwd: URL) async throws -> String {
        let result = try await runCLI("railway init -n \"\(name)\"", cwd: cwd, timeout: 30)
        guard result.exitCode == 0 else {
            throw RailwayError.commandFailed("railway init", result.output)
        }
        return result.output
    }

    /// Deploy to Railway via Nixpacks (detached)
    static func deploy(serviceName: String, cwd: URL) async throws -> String {
        let result = try await runCLI("railway up --detach --service \"\(serviceName)\"", cwd: cwd, timeout: 120)
        guard result.exitCode == 0 else {
            throw RailwayError.commandFailed("railway up", result.output)
        }
        return result.output
    }

    /// Get the public domain for a service
    static func getDomain(serviceName: String, cwd: URL) async throws -> String {
        let result = try await runCLI("railway domain --json --service \"\(serviceName)\"", cwd: cwd, timeout: 30)
        guard result.exitCode == 0 else {
            throw RailwayError.commandFailed("railway domain", result.output)
        }

        // Parse JSON: {"domain": "https://name-production.up.railway.app"}
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let domain = json["domain"] as? String {
            return domain
        }

        // Fallback: find URL in raw output
        if let range = output.range(of: #"https://[\w-]+-production\.up\.railway\.app"#, options: .regularExpression) {
            return String(output[range])
        }

        throw RailwayError.noDomain(output)
    }

    /// Poll deployment status until SUCCESS or timeout
    static func pollStatus(cwd: URL, maxAttempts: Int = 30, interval: UInt64 = 2_000_000_000) async throws -> String {
        for attempt in 0..<maxAttempts {
            let result = try await runCLI("railway service status --all", cwd: cwd, timeout: 15)
            let output = result.output.uppercased()

            if output.contains("SUCCESS") {
                return "SUCCESS"
            }
            if output.contains("FAILED") || output.contains("CRASHED") {
                throw RailwayError.deployFailed(result.output)
            }

            // Still deploying — wait and retry
            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: interval)
            }
        }

        return "TIMEOUT"
    }

    // MARK: - Private

    private static func runCLI(_ command: String, cwd: URL, timeout: TimeInterval = 60) async throws -> (exitCode: Int, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]
            process.currentDirectoryURL = cwd
            process.standardOutput = pipe
            process.standardError = pipe

            var environment = ProcessInfo.processInfo.environment
            let extraPaths = [
                "/usr/local/bin",
                "/opt/homebrew/bin",
                "/usr/local/share/npm/bin",
                "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/v20/bin",
            ]
            let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
            environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
            process.environment = environment

            process.terminationHandler = { terminatedProcess in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (
                    exitCode: Int(terminatedProcess.terminationStatus),
                    output: output
                ))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: RailwayError.processLaunchFailed(error.localizedDescription))
                return
            }

            Task.detached {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }

    /// Synchronous check (for `isAvailable` — no async context needed)
    private static func runCLISync(_ command: String) -> (exitCode: Int, output: String)? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (exitCode: Int(process.terminationStatus), output: output)
        } catch {
            return nil
        }
    }
}

// MARK: - Errors

enum RailwayError: LocalizedError {
    case commandFailed(String, String)
    case noDomain(String)
    case deployFailed(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let output):
            return "Railway CLI failed (\(cmd)): \(output.prefix(200))"
        case .noDomain(let output):
            return "Could not parse Railway domain: \(output.prefix(200))"
        case .deployFailed(let output):
            return "Railway deploy failed: \(output.prefix(200))"
        case .processLaunchFailed(let detail):
            return "Could not launch Railway CLI: \(detail)"
        }
    }
}
