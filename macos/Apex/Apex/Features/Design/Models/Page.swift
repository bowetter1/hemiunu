import Foundation

/// A page in a project
struct Page: Identifiable, Codable {
    let id: String
    let name: String
    let html: String
    let layoutVariant: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, html
        case layoutVariant = "layout_variant"
    }
}
