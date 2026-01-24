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
        }
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
