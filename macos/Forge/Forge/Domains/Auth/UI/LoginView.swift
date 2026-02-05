import SwiftUI

/// Login screen — Google Sign-In and error handling
struct LoginView: View {
    @ObservedObject var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Forge")
                .font(.system(size: 40, weight: .bold))

            Text("AI Website Builder")
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
                _ = try await appState.authService.signInWithGoogle()
                await appState.didSignIn()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
