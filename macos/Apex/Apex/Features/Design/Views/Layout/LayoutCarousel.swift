import SwiftUI

/// View for displaying and selecting layout alternatives - one at a time with dot navigation
struct LayoutCarousel: View {
    let pages: [Page]
    var projectId: String? = nil
    @Binding var selectedVariant: Int?
    let onSelect: () -> Void

    @State private var currentIndex: Int = 0

    // Filter to only layout variants
    var layoutVariants: [Page] {
        pages.filter { $0.layoutVariant != nil }.sorted { ($0.layoutVariant ?? 0) < ($1.layoutVariant ?? 0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Full-size preview of current layout
            if !layoutVariants.isEmpty && currentIndex < layoutVariants.count {
                HTMLWebView(html: layoutVariants[currentIndex].html, projectId: projectId)
                    .ignoresSafeArea()
            }

            // Navigation overlay at top
            VStack(spacing: 0) {
                // Dot navigation
                HStack(spacing: 12) {
                    ForEach(Array(layoutVariants.enumerated()), id: \.offset) { index, page in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex = index
                                selectedVariant = page.layoutVariant
                            }
                        } label: {
                            Circle()
                                .fill(currentIndex == index ? Color.primary : Color.secondary.opacity(0.4))
                                .frame(width: currentIndex == index ? 10 : 8, height: currentIndex == index ? 10 : 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.top, 16)

                Spacer()

                // Continue button at bottom
                if selectedVariant != nil {
                    Button(action: onSelect) {
                        HStack(spacing: 8) {
                            Text("Use this layout")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(100)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Select first layout by default
            if selectedVariant == nil && !layoutVariants.isEmpty {
                selectedVariant = layoutVariants[0].layoutVariant
            }
        }
    }
}
