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

/// Kill only boss processes that Apex previously spawned.
/// PIDs are tracked in `~/Apex/projects/.boss-pids` — written at spawn, cleared here.
private func killOrphanedBossProcesses() {
    let pidsFile = BossPIDFile.url
    guard let content = try? String(contentsOf: pidsFile, encoding: .utf8) else { return }

    for line in content.components(separatedBy: .newlines) {
        guard let pid = Int32(line.trimmingCharacters(in: .whitespaces)), pid > 0 else { continue }
        // Only kill if the process still exists (kill 0 checks without signalling)
        if kill(pid, 0) == 0 {
            kill(pid, SIGTERM)
            print("[Cleanup] Killed orphaned boss process (PID \(pid))")
        }
    }

    // Clear the file — these PIDs are now handled
    try? "".write(to: pidsFile, atomically: true, encoding: .utf8)
}

// MARK: - Boss PID Tracking

/// Shared PID file for tracking boss-spawned processes across app launches.
enum BossPIDFile {
    static let url: URL = {
        let root = LocalWorkspaceService.shared.rootDirectory
        return root.appendingPathComponent(".boss-pids")
    }()

    /// Record a PID when a boss process is spawned
    static func add(_ pid: Int32) {
        let fileURL = url
        var existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        existing += "\(pid)\n"
        try? existing.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Remove a PID when a boss process exits normally
    static func remove(_ pid: Int32) {
        let fileURL = url
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        content = content
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces) != "\(pid)" }
            .joined(separator: "\n")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
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
