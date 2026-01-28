import SwiftUI

// MARK: - Settings Tool Card

struct SettingsToolCard: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = false
    @State private var showTelegramSheet = false

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
                VStack(spacing: 2) {
                    SettingsRow(icon: "globe", title: "Domain", subtitle: "mysite.com")
                    SettingsRow(icon: "key", title: "Environment", subtitle: "3 variables")
                    SettingsRow(icon: "link", title: "Integrations", subtitle: "Supabase, Stripe")

                    // Telegram row
                    Button(action: { showTelegramSheet = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Telegram")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Koppla mobil-notiser")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    SettingsRow(icon: "square.and.arrow.up", title: "Export", subtitle: "Download project")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .sheet(isPresented: $showTelegramSheet) {
            TelegramLinkSheet(client: appState.client)
        }
    }
}

// MARK: - Telegram Link Sheet

struct TelegramLinkSheet: View {
    let client: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var linkCode: String?
    @State private var isLoading = false
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Koppla Telegram")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Hämtar kod...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let code = linkCode {
                VStack(spacing: 16) {
                    Text("Din kod:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Large code display
                    HStack(spacing: 8) {
                        ForEach(Array(code), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .frame(width: 36, height: 48)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    // Copy button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    }) {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Kopierad!" : "Kopiera kod")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(copied ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(number: 1, text: "Öppna Telegram")
                        InstructionRow(number: 2, text: "Sök efter @ApexDesignBot")
                        InstructionRow(number: 3, text: "Skriv koden: \(code)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Koden är giltig i 5 minuter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Försök igen") {
                        fetchCode()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: 400)
        .onAppear {
            fetchCode()
        }
    }

    private func fetchCode() {
        isLoading = true
        error = nil

        Task {
            do {
                let response = try await client.authService.getTelegramLinkCode()
                await MainActor.run {
                    linkCode = response.code
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
