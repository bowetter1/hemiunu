import Foundation

/// Container for research data (brand colors + inspiration sites)
/// Note: Still called MoodboardContainer for backward compatibility with API
struct MoodboardContainer: Codable {
    // New research-based fields
    let brandColors: [String]?
    let fonts: MoodboardFonts?
    let inspirationSites: [InspirationSite]?
    let research: MoodboardResearch?

    // Legacy moodboard fields (kept for backward compatibility)
    let moodboards: [Moodboard]?
    let recommended: Int?
    let recommendationReason: String?

    enum CodingKeys: String, CodingKey {
        case brandColors = "brand_colors"
        case fonts
        case inspirationSites = "inspiration_sites"
        case research
        case moodboards, recommended
        case recommendationReason = "recommendation_reason"
    }

    /// Get the brand colors (from new format or fallback to old moodboard)
    var colors: [String] {
        if let colors = brandColors, !colors.isEmpty {
            return colors
        }
        // Fallback to first moodboard's palette
        return moodboards?.first?.palette ?? []
    }

    /// Get the fonts (from new format or fallback to old moodboard)
    var fontsToUse: MoodboardFonts {
        if let f = fonts {
            return f
        }
        // Fallback to first moodboard's fonts
        return moodboards?.first?.fonts ?? MoodboardFonts(heading: "Inter", body: "Inter")
    }

    /// Get all inspiration sites (from new format or research)
    var allInspirationSites: [InspirationSite] {
        if let sites = inspirationSites, !sites.isEmpty {
            return sites
        }
        return research?.inspirationSites ?? []
    }
}

/// Research data including inspiration sites
struct MoodboardResearch: Codable {
    let summary: String?
    let inspirationSites: [InspirationSite]?
    let colorsFound: [String]?
    let brandColors: [String]?
    let companyUrl: String?
    let searchQueries: [String]?

    enum CodingKeys: String, CodingKey {
        case summary
        case inspirationSites = "inspiration_sites"
        case colorsFound = "colors_found"
        case brandColors = "brand_colors"
        case companyUrl = "company_url"
        case searchQueries = "search_queries"
    }
}

/// An inspiration website found during research
struct InspirationSite: Codable, Identifiable {
    var id: String { url }
    let url: String
    let name: String
    let why: String
    let designStyle: String?
    let keyElements: [String]?

    enum CodingKeys: String, CodingKey {
        case url, name, why
        case designStyle = "design_style"
        case keyElements = "key_elements"
    }
}

/// Legacy Moodboard data (kept for backward compatibility)
struct Moodboard: Codable, Identifiable {
    var id: String { name }
    let name: String            // "Minimalistisk", "Varm & Organisk", etc.
    let palette: [String]       // ["#hex1", "#hex2", ...]
    let fonts: MoodboardFonts
    let mood: [String]          // ["modern", "clean", ...]
    let rationale: String
}

struct MoodboardFonts: Codable {
    let heading: String
    let body: String
}
