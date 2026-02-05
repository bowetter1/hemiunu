import SwiftUI

// MARK: - Settings Tool Card

struct SettingsToolCard: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)

                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    // Groq API Key
                    APIKeyRow(
                        provider: .groq,
                        icon: "bolt.fill",
                        color: .orange
                    )

                    // Claude API Key
                    APIKeyRow(
                        provider: .claude,
                        icon: "sparkles",
                        color: .purple
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Theme.Colors.glassFill)
        .cornerRadius(8)
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    let provider: AIProvider
    let icon: String
    let color: Color

    @State private var isEditing = false
    @State private var keyText = ""
    @State private var hasKey = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Text(hasKey ? "API key saved" : "No API key")
                        .font(.system(size: 9))
                        .foregroundColor(hasKey ? .green : .secondary)
                }

                Spacer()

                Button(action: {
                    if isEditing {
                        saveKey()
                    } else {
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "Save" : (hasKey ? "Change" : "Add"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                if hasKey && !isEditing {
                    Button(action: deleteKey) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)

            if isEditing {
                SecureField("Paste API key...", text: $keyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .onSubmit { saveKey() }
            }
        }
        .background(Theme.Colors.glassFill)
        .cornerRadius(6)
        .onAppear { checkKey() }
    }

    private func checkKey() {
        hasKey = KeychainHelper.load(key: provider.keychainKey) != nil
    }

    private func saveKey() {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(key: provider.keychainKey, value: trimmed)
        keyText = ""
        isEditing = false
        hasKey = true
    }

    private func deleteKey() {
        KeychainHelper.delete(key: provider.keychainKey)
        hasKey = false
        keyText = ""
    }
}
