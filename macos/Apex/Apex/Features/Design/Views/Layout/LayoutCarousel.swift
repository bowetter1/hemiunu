import SwiftUI

/// View for displaying and selecting layout alternatives
struct LayoutCarousel: View {
    let pages: [Page]
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    // Filter to only layout variants
    var layoutVariants: [Page] {
        pages.filter { $0.layoutVariant != nil }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a layout")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(layoutVariants) { page in
                        LayoutCard(
                            page: page,
                            isSelected: selectedVariant == page.layoutVariant
                        ) {
                            selectedVariant = page.layoutVariant
                        }
                    }
                }
                .padding(.horizontal, 40)
            }

            if selectedVariant != nil {
                Button(action: onSelect) {
                    Text("Continue with this layout")
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

struct LayoutCard: View {
    let page: Page
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Mini preview
                HTMLWebView(html: page.html)
                    .frame(width: 300, height: 400)
                    .cornerRadius(8)
                    .clipped()

                Text("Layout \(page.layoutVariant ?? 0)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(12)
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
