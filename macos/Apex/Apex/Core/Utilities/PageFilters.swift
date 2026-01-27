import Foundation

/// Shared page filtering utilities used across sidebar views
enum PageFilters {
    /// Root pages (pages without a parent — layout/hero pages)
    static func rootPages(from pages: [Page]) -> [Page] {
        pages.filter { $0.parentPageId == nil }
    }

    /// Child pages for a given parent page
    static func childPages(for parentId: String, from pages: [Page]) -> [Page] {
        pages.filter { $0.parentPageId == parentId }
    }

    /// Pages belonging to a specific variant
    static func pagesForVariant(_ variantId: String, from pages: [Page]) -> [Page] {
        pages.filter { $0.variantId == variantId }
    }

    /// Pages that have no variant assigned
    static func pagesWithoutVariant(from pages: [Page]) -> [Page] {
        pages.filter { $0.variantId == nil }
    }
}
