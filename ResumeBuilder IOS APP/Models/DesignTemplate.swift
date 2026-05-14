import Foundation

struct DesignTemplate: Identifiable, Codable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String
    let category: String    // "ats_safe" | "modern" | "creative"
    var isPremium: Bool
    var thumbnailURL: String?
    var atsScore: Int?

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, description, category
        case isPremium    = "is_premium"
        case thumbnailURL = "thumbnail_url"
        case atsScore     = "ats_score"
    }
}

struct DesignCustomization: Codable, Sendable {
    var spacing: Double         // 0.0 – 1.0
    var accentColor: String     // hex string
    var fontStyle: String       // "classic" | "modern" | "minimal"

    static let `default` = DesignCustomization(spacing: 0.5, accentColor: "6366F1", fontStyle: "modern")

    private enum CodingKeys: String, CodingKey {
        case spacing
        case accentColor = "accent_color"
        case fontStyle   = "font_style"
    }
}
