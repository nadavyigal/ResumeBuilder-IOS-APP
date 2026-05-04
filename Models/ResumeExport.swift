import Foundation

struct ResumeExport: Identifiable, Codable, Sendable {
    let id: String
    let filename: String
    var kind: ExportKind
    let createdAt: String
    var fileURL: String?

    enum ExportKind: String, Codable, Sendable {
        case optimized, designed
    }

    private enum CodingKeys: String, CodingKey {
        case id, filename, kind
        case createdAt = "created_at"
        case fileURL   = "file_url"
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
