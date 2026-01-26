import SwiftUI

/// Displays brand colors and inspiration sites in the tools panel
struct MoodboardSelector: View {
    let moodboard: MoodboardContainer?

    @State private var isExpanded = true
    @State private var showInspiration = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            if isExpanded, let data = moodboard {
                Divider()

                // Brand colors
                brandColorsSection(colors: data.colors)

                // Inspiration sites
                if !data.allInspirationSites.isEmpty {
                    Divider()
                    inspirationSection(sites: data.allInspirationSites)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var headerView: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                Image(systemName: "paintbrush")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)

                Text("Brand & Inspiration")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private func brandColorsSection(colors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("Brand Colors")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Color swatches
            HStack(spacing: 4) {
                ForEach(colors.prefix(5), id: \.self) { color in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: color) ?? .gray)
                            .frame(width: 40, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                        Text(color.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }

    private func inspirationSection(sites: [InspirationSite]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { showInspiration.toggle() } }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)

                    Text("Inspiration Sites (\(sites.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: showInspiration ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if showInspiration {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sites.enumerated()), id: \.element.id) { index, site in
                        InspirationSiteRow(site: site, layoutNumber: index + 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

/// Single inspiration site row with layout indicator
struct InspirationSiteRow: View {
    let site: InspirationSite
    let layoutNumber: Int

    var body: some View {
        Button(action: openURL) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Layout indicator
                    Text("L\(layoutNumber)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(3)

                    Text(site.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                // Design style
                if let style = site.designStyle, !style.isEmpty {
                    Text(style)
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                // Why inspiring
                Text(site.why)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Key elements
                if let elements = site.keyElements, !elements.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(elements.prefix(3), id: \.self) { element in
                            Text(element)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func openURL() {
        if let url = URL(string: site.url) {
            NSWorkspace.shared.open(url)
        }
    }
}
