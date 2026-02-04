//
//  ApexApp.swift
//  Apex
//
//  Created by Bo Wetter on 2026-01-20.
//

import SwiftUI
import FirebaseCore

@main
struct ApexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    init() {
        FirebaseApp.configure()
        killOrphanedBossProcesses()
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .preferredColorScheme(appState.appearanceMode.colorScheme)
                .background(WindowAccessor())
                .onAppear {
                    NotificationService.shared.requestPermission()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appSettings) {
                Picker("Appearance", selection: $appState.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        let boss = AppState.shared.chatViewModel.boss
        boss.stopAll()
    }
}

// MARK: - Orphaned Process Cleanup

/// Kill any orphaned boss processes from previous runs.
/// Scans for stale `claude`/`gemini`/`kimi`/`codex` processes whose working directory
/// matches a `session-*/boss-*` workspace path.
private func killOrphanedBossProcesses() {
    let rootPath = LocalWorkspaceService.shared.rootDirectory.path
    let cliNames = ["claude", "gemini", "kimi", "codex"]

    for name in cliNames {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { continue }

        for pidStr in output.components(separatedBy: .newlines) {
            guard let pid = Int32(pidStr.trimmingCharacters(in: .whitespaces)), pid > 0 else { continue }

            // Check if the process's cwd is inside our workspace
            let cwdProcess = Process()
            cwdProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            cwdProcess.arguments = ["-p", "\(pid)", "-Fn", "-d", "cwd"]
            let cwdPipe = Pipe()
            cwdProcess.standardOutput = cwdPipe
            cwdProcess.standardError = FileHandle.nullDevice
            try? cwdProcess.run()
            cwdProcess.waitUntilExit()

            let cwdData = cwdPipe.fileHandleForReading.readDataToEndOfFile()
            if let cwdOutput = String(data: cwdData, encoding: .utf8),
               cwdOutput.contains(rootPath),
               cwdOutput.contains("session-") {
                kill(pid, SIGTERM)
                print("[Cleanup] Killed orphaned \(name) process (PID \(pid))")
            }
        }
    }
}

// MARK: - Window Configuration

/// Helper to configure NSWindow for full-size content with traffic lights
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Enable full-size content view
                window.styleMask.insert(.fullSizeContentView)

                // Make title bar transparent
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden

                // Keep traffic lights visible
                window.standardWindowButton(.closeButton)?.isHidden = false
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                window.standardWindowButton(.zoomButton)?.isHidden = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
