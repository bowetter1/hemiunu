import SwiftUI
import AppKit

/// Modern moodboard picker with large color swatches
struct MoodboardPicker: View {
    let moodboards: [Moodboard]
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 8) {
                Text("Select Direction")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Choose the visual direction for your project")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Moodboard cards
            HStack(spacing: 24) {
                ForEach(Array(moodboards.enumerated()), id: \.offset) { index, moodboard in
                    MoodboardPickerCard(
                        moodboard: moodboard,
                        index: index + 1,
                        isSelected: selectedVariant == index
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedVariant = index
                        }
                    }
                }
            }
            .padding(.horizontal, 40)

            // Continue button
            if selectedVariant != nil {
                Button(action: onSelect) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .cornerRadius(100)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MoodboardPickerCard: View {
    let moodboard: Moodboard
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            colorBoxes
            rationaleText
            moodTags
            fontPreviews
        }
        .padding(16)
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(selectionBorder)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var headerRow: some View {
        HStack {
            Text(moodboard.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            Text("\(index)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }

    private var colorBoxes: some View {
        HStack(spacing: 10) {
            ForEach(Array(moodboard.palette.prefix(3).enumerated()), id: \.offset) { _, color in
                ColorBox(hex: color)
            }
        }
    }

    private var rationaleText: some View {
        Text(moodboard.rationale)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var moodTags: some View {
        HStack(spacing: 5) {
            ForEach(moodboard.mood.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(100)
            }
        }
    }

    private var fontPreviews: some View {
        HStack(spacing: 16) {
            FontPreview(label: "Heading", fontName: moodboard.fonts.heading, size: 14)
            FontPreview(label: "Body", fontName: moodboard.fonts.body, size: 13)
        }
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
    }

    private var shadowColor: Color {
        isSelected ? Color.primary.opacity(0.2) : Color.black.opacity(0.08)
    }

    private var shadowRadius: CGFloat { isSelected ? 20 : 10 }
    private var shadowY: CGFloat { isSelected ? 8 : 4 }
}

// MARK: - Color Box

private struct ColorBox: View {
    let hex: String

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            Text(hex.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Font Preview

private struct FontPreview: View {
    let label: String
    let fontName: String
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(fontName)
                .font(resolvedFont)
                .foregroundColor(.primary)
        }
    }

    private var resolvedFont: Font {
        // Try exact font name
        if let nsFont = NSFont(name: fontName, size: size) {
            return Font(nsFont)
        }

        // Try without spaces
        let noSpaces = fontName.replacingOccurrences(of: " ", with: "")
        if let nsFont = NSFont(name: noSpaces, size: size) {
            return Font(nsFont)
        }

        // Fallback based on font type
        let lower = fontName.lowercased()
        if lower.contains("serif") || lower.contains("georgia") || lower.contains("times") {
            return .system(size: size, weight: .regular, design: .serif)
        }
        if lower.contains("mono") || lower.contains("code") {
            return .system(size: size, weight: .regular, design: .monospaced)
        }
        if lower.contains("rounded") {
            return .system(size: size, weight: .regular, design: .rounded)
        }

        return .system(size: size, weight: .medium)
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
