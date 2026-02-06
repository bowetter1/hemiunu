import SwiftUI
import FirebaseCore
import AppKit

@main
struct ForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    init() {
        FirebaseApp.configure()
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
        // Clean shutdown
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
