import SwiftUI

// MARK: - Design Tool Card

struct DesignToolCard: View {
    @State private var isExpanded = false
    @State private var selectedViewport: String = "desktop"
    @State private var zoomLevel: Double = 100

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .frame(width: 28, height: 28)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)

                    Text("Design")
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
                VStack(alignment: .leading, spacing: 12) {
                    // Viewport selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Viewport")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            ViewportButton(icon: "desktopcomputer", label: "Desktop", isSelected: selectedViewport == "desktop") {
                                selectedViewport = "desktop"
                            }
                            ViewportButton(icon: "tablet", label: "Tablet", isSelected: selectedViewport == "tablet") {
                                selectedViewport = "tablet"
                            }
                            ViewportButton(icon: "iphone", label: "Mobile", isSelected: selectedViewport == "mobile") {
                                selectedViewport = "mobile"
                            }
                        }
                    }

                    // Zoom
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zoom")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: { zoomLevel = max(50, zoomLevel - 10) }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Text("\(Int(zoomLevel))%")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .frame(width: 40)

                            Button(action: { zoomLevel = min(200, zoomLevel + 10) }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    // Brand Colors (mockup)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brand Colors")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ColorSwatch(color: .orange)
                            ColorSwatch(color: .black)
                            ColorSwatch(color: Color(white: 0.95))
                            ColorSwatch(color: .blue)
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Typography (mockup)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Typography")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Heading:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Inter Bold")
                                .font(.system(size: 10, weight: .medium))
                        }
                        HStack {
                            Text("Body:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Inter Regular")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ViewportButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 8))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple : Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ColorSwatch: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}
