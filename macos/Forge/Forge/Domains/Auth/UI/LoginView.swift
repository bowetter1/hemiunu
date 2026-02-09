import SwiftUI

/// Login screen — Google Sign-In and error handling
struct LoginView: View {
    var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Forge")
                .font(.system(size: 40, weight: .bold))

            Text("AI Design Studio")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sign in with Google", systemImage: "person.badge.key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if let appError = appState.errorMessage, appError != errorMessage {
                Text(appError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                #if DEBUG
                print("[Auth] Starting Google Sign-In...")
                #endif
                let token = try await appState.authService.signInWithGoogle()
                #if DEBUG
                print("[Auth] Got Firebase token: \(token.prefix(20))...")
                #endif
                await appState.didSignIn()
                #if DEBUG
                print("[Auth] didSignIn() completed")
                #endif
            } catch {
                #if DEBUG
                print("[Auth] Sign-in error: \(error)")
                #endif
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
