import Foundation

/// A design variant within a project
struct Variant: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let moodboardIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case moodboardIndex = "moodboard_index"
    }
}

/// A page in a variant
struct Page: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let html: String
    let variantId: String?
    let parentPageId: String?  // Parent layout/hero page
    let layoutVariant: Int?  // Legacy, kept for compatibility
    let currentVersion: Int

    enum CodingKeys: String, CodingKey {
        case id, name, html
        case variantId = "variant_id"
        case parentPageId = "parent_page_id"
        case layoutVariant = "layout_variant"
        case currentVersion = "current_version"
    }

    // Memberwise initializer
    init(id: String, name: String, html: String, variantId: String? = nil, parentPageId: String? = nil, layoutVariant: Int? = nil, currentVersion: Int = 1) {
        self.id = id
        self.name = name
        self.html = html
        self.variantId = variantId
        self.parentPageId = parentPageId
        self.layoutVariant = layoutVariant
        self.currentVersion = currentVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        html = try container.decode(String.self, forKey: .html)
        variantId = try container.decodeIfPresent(String.self, forKey: .variantId)
        parentPageId = try container.decodeIfPresent(String.self, forKey: .parentPageId)
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
