import Foundation

struct SavedResume: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let filename: String
    let displayName: String?
    let createdAt: String
    let sizeBytes: Int?
    let optimizationId: String?

    init(
        id: String,
        filename: String,
        displayName: String?,
        createdAt: String,
        sizeBytes: Int?,
        optimizationId: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.displayName = displayName
        self.createdAt = createdAt
        self.sizeBytes = sizeBytes
        self.optimizationId = optimizationId
    }

    private enum CodingKeys: String, CodingKey {
        case id, filename
        case displayName = "display_name"
        case createdAt = "created_at"
        case sizeBytes = "size_bytes"
        case optimizationId = "optimization_id"
    }
}

struct SavedResumesResponse: Codable, Sendable {
    let resumes: [SavedResume]
}

struct SaveResumeResponse: Codable, Sendable {
    let success: Bool
    let resume: SavedResume?
}
