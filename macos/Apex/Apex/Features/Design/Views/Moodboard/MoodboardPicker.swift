import SwiftUI

/// View for displaying and selecting moodboard alternatives
struct MoodboardPicker: View {
    let moodboards: [Moodboard]
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a moodboard")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(moodboards.enumerated()), id: \.offset) { index, moodboard in
                        MoodboardPickerCard(
                            moodboard: moodboard,
                            isSelected: selectedVariant == index
                        ) {
                            selectedVariant = index
                        }
                    }
                }
                .padding(.horizontal, 40)
            }

            if selectedVariant != nil {
                Button(action: onSelect) {
                    Text("Continue with this moodboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MoodboardPickerCard: View {
    let moodboard: Moodboard
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                Text(moodboard.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Color palette
                HStack(spacing: 4) {
                    ForEach(moodboard.palette, id: \.self) { color in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: color) ?? .gray)
                            .frame(width: 32, height: 32)
                    }
                }

                // Fonts
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heading: \(moodboard.fonts.heading)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Body: \(moodboard.fonts.body)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Mood tags
                HStack(spacing: 4) {
                    ForEach(moodboard.mood, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                // Rationale
                Text(moodboard.rationale)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(20)
            .frame(width: 280)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// Color extension for hex parsing
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
