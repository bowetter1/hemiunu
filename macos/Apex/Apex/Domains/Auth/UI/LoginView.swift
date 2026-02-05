import SwiftUI

/// Login screen — Google Sign-In, pending approval state, and error handling
struct LoginView: View {
    @ObservedObject var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Apex")
                .font(.system(size: 40, weight: .bold))

            Text("AI Design Studio")
                .font(.title3)
                .foregroundStyle(.secondary)

            if appState.isPendingApproval {
                // Pending state
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text("Your account is awaiting admin approval.")
                        .foregroundStyle(.secondary)

                    Button("Retry") {
                        Task { await appState.connect() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Sign in
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
                print("[Auth] Starting Google Sign-In...")
                let token = try await appState.client.auth.signInWithGoogle()
                print("[Auth] Got Firebase token: \(token.prefix(20))...")
                await appState.didSignIn()
                print("[Auth] didSignIn() completed")
            } catch {
                print("[Auth] Sign-in error: \(error)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
