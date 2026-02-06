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
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: - Layout

    enum Layout {
        static let sidebarWidth: CGFloat = 220
        static let topbarHeight: CGFloat = 36
    }
}
