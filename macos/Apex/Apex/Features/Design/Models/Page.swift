import Foundation

/// A page in a project
struct Page: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let html: String
    let layoutVariant: Int?
    let currentVersion: Int

    enum CodingKeys: String, CodingKey {
        case id, name, html
        case layoutVariant = "layout_variant"
        case currentVersion = "current_version"
    }

    // Memberwise initializer (needed because custom decoder removes synthesized one)
    init(id: String, name: String, html: String, layoutVariant: Int?, currentVersion: Int = 1) {
        self.id = id
        self.name = name
        self.html = html
        self.layoutVariant = layoutVariant
        self.currentVersion = currentVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        html = try container.decode(String.self, forKey: .html)
        layoutVariant = try container.decodeIfPresent(Int.self, forKey: .layoutVariant)
        currentVersion = try container.decodeIfPresent(Int.self, forKey: .currentVersion) ?? 1
    }
}

/// A version of a page
struct PageVersion: Identifiable, Codable {
    let id: String
    let version: Int
    let instruction: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, version, instruction
        case createdAt = "created_at"
    }
}
