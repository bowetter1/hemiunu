import SwiftUI

// MARK: - Settings Tool Card

struct SettingsToolCard: View {
    @Bindable var appState: AppState
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                        .frame(width: 32)

                    Text("Settings")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().opacity(0.35)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                VStack(spacing: 8) {
                    // AI Provider picker
                    HStack(spacing: 10) {
                        Image(systemName: "brain")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Provider")
                                .font(.system(size: 11, weight: .medium))
                            Text(appState.selectedProvider.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: $appState.selectedProvider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.shortLabel).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)

                    // Appearance
                    HStack(spacing: 10) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        Text("Appearance")
                            .font(.system(size: 11, weight: .medium))

                        Spacer()

                        Picker("", selection: $appState.appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}
