import Foundation

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

struct ResumeExport: Identifiable, Codable, Sendable {
    let id: String
    let filename: String
    var kind: ExportKind
    let createdAt: String
    var fileURL: String?
    var optimizationId: String?
    var matchScore: Int?

    enum ExportKind: String, Codable, Sendable {
        case optimized, designed
    }

    private enum CodingKeys: String, CodingKey {
        case id, filename, kind
        case createdAt = "created_at"
        case fileURL   = "file_url"
        case optimizationId = "optimization_id"
        case matchScore = "match_score"
    }

    init(
        id: String,
        filename: String,
        kind: ExportKind,
        createdAt: String,
        fileURL: String?,
        optimizationId: String? = nil,
        matchScore: Int? = nil
    ) {
        self.id = id
        self.filename = filename
        self.kind = kind
        self.createdAt = createdAt
        self.fileURL = fileURL
        self.optimizationId = optimizationId
        self.matchScore = matchScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("optimizationId"))
            ?? UUID().uuidString
        let jobTitle = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("jobTitle"))
        let company = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("company"))
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
            ?? [jobTitle, company].compactMap { $0 }.joined(separator: " · ")
            .nonEmpty
            ?? "Optimized Resume"
        kind = try container.decodeIfPresent(ExportKind.self, forKey: .kind) ?? .optimized
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("createdAt"))
            ?? ""
        fileURL = try container.decodeIfPresent(String.self, forKey: .fileURL)
            ?? dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("downloadURL"))
        optimizationId = try container.decodeIfPresent(String.self, forKey: .optimizationId)
        matchScore = try container.decodeIfPresent(Int.self, forKey: .matchScore)
            ?? dynamic.decodeIfPresent(Int.self, forKey: DynamicCodingKey("matchScore"))
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: createdAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return createdAt
    }
}

struct OptimizationListResponse: Codable, Sendable {
    let optimizations: [ResumeExport]
}

struct ExportResponse: Codable, Sendable {
    let success: Bool?
    let exportId: String?
    let downloadURL: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success
        case exportId    = "export_id"
        case downloadURL = "download_url"
        case error
    }
}
