import Foundation

/// Container for multiple moodboard alternatives
struct MoodboardContainer: Codable {
    let moodboards: [Moodboard]
}

/// Moodboard data from AI
struct Moodboard: Codable {
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
