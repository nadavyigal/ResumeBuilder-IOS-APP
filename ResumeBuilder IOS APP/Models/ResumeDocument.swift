import Foundation

struct ResumeDocument: Identifiable, Codable, Sendable {
    let id: String
    let filename: String
    let size: Int?
    let createdAt: String
    var status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case filename
        case size
        case createdAt = "created_at"
        case status
    }

    var formattedSize: String {
        guard let size else { return "" }
        if size > 1_000_000 { return String(format: "%.1f MB", Double(size) / 1_000_000) }
        return String(format: "%.0f KB", Double(size) / 1_000)
    }
}
