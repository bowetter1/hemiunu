//
//  ApexApp.swift
//  Apex
//
//  Created by Bo Wetter on 2026-01-20.
//

import SwiftUI

@main
struct ApexApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .preferredColorScheme(appState.appearanceMode.colorScheme)
                .background(WindowAccessor())
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
