import Foundation

struct SavedResume: Identifiable, Codable, Sendable {
    let id: String
    let filename: String
    let displayName: String?
    let createdAt: String
    let sizeBytes: Int?

    private enum CodingKeys: String, CodingKey {
        case id, filename
        case displayName = "display_name"
        case createdAt = "created_at"
        case sizeBytes = "size_bytes"
    }
}

struct SavedResumesResponse: Codable, Sendable {
    let resumes: [SavedResume]
}

struct SaveResumeResponse: Codable, Sendable {
    let success: Bool
    let resume: SavedResume?
}
