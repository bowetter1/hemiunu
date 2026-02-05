import SwiftUI

/// App-wide design tokens
enum Theme {
    // MARK: - Colors

    enum Colors {
        static let accent = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red

        static let background = Color(nsColor: .windowBackgroundColor)
        static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
        static let tertiaryBackground = Color(nsColor: .textBackgroundColor)

        static let glassFill = Color.primary.opacity(0.06)
        static let glassFillHover = Color.primary.opacity(0.12)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Layout

    enum Layout {
        static let sidebarWidth: CGFloat = 240
        static let topbarHeight: CGFloat = 44
    }
}
