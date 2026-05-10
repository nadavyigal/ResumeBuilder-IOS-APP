import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct APIStatusResponse: Codable, Sendable {
    let success: Bool?
    let error: String?
}

/// Response shape returned by POST /api/ats/score (authenticated endpoint).
/// Distinct from ATSScoreResult which is used by /api/public/ats-check.
struct ATSAuthScoreResult: Codable, Sendable {
    let atsScoreOriginal: Int
    let atsScoreOptimized: Int
    let confidence: Double?

    private enum CodingKeys: String, CodingKey {
        case atsScoreOriginal  = "ats_score_original"
        case atsScoreOptimized = "ats_score_optimized"
        case confidence
    }
}

/// Response shape returned by GET /api/resumes/{id}.
struct ResumeTextResponse: Codable, Sendable {
    let rawText: String

    private enum CodingKeys: String, CodingKey {
        case rawText = "raw_text"
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

struct OptimizationSummary: Codable, Sendable {
    let atsScore: Int
    let contentScore: Int?
    let designScore: Int?
    let keywordScore: Int?

    init(item: OptimizationHistoryItem) {
        atsScore = item.matchScorePercent
        contentScore = item.contentScorePercent
        designScore = item.designScorePercent
        keywordScore = item.keywordScorePercent
    }
}

struct OptimizationHistoryResponse: Codable, Sendable {
    let success: Bool?
    let optimizations: [OptimizationHistoryItem]?
    let data: [OptimizationHistoryItem]?
    let items: [OptimizationHistoryItem]?
    let pagination: PaginationMeta?

    var allItems: [OptimizationHistoryItem] {
        optimizations ?? data ?? items ?? []
    }
}

struct PaginationMeta: Codable, Sendable {
    let page: Int?
    let limit: Int?
    let total: Int?
    let hasMore: Bool?
    let totalPages: Int?
}

struct BulkDeleteResponse: Codable, Sendable {
    let success: Bool
    let deleted: Int?
    let errors: [BulkDeleteError]?

    struct BulkDeleteError: Codable, Sendable {
        let id: String
        let error: String
    }
}

struct OptimizationHistoryItem: Codable, Identifiable, Sendable {
    let id: String
    let createdAt: String
    let jobTitle: String?
    let company: String?
    let matchScorePercent: Int
    let contentScorePercent: Int?
    let designScorePercent: Int?
    let keywordScorePercent: Int?
    let status: String?
    let jobUrl: String?
    let templateKey: String?
    let resumeId: String?

    init(
        id: String,
        createdAt: String,
        jobTitle: String?,
        company: String?,
        matchScorePercent: Int,
        contentScorePercent: Int? = nil,
        designScorePercent: Int? = nil,
        keywordScorePercent: Int? = nil,
        status: String? = nil,
        jobUrl: String? = nil,
        templateKey: String? = nil,
        resumeId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.jobTitle = jobTitle
        self.company = company
        self.matchScorePercent = matchScorePercent
        self.contentScorePercent = contentScorePercent
        self.designScorePercent = designScorePercent
        self.keywordScorePercent = keywordScorePercent
        self.status = status
        self.jobUrl = jobUrl
        self.templateKey = templateKey
        self.resumeId = resumeId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        id = try container.decodeString(for: ["id", "optimizationId", "optimization_id"]) ?? UUID().uuidString
        createdAt = try container.decodeString(for: ["createdAt", "created_at"]) ?? ""
        jobTitle = try container.decodeString(for: ["jobTitle", "job_title", "title"])
        company = try container.decodeString(for: ["company", "companyName", "company_name"])
        matchScorePercent = try container.decodePercent(for: ["matchScore", "match_score", "atsScore", "ats_score"]) ?? 0
        contentScorePercent = try container.decodePercent(for: ["contentScore", "content_score"])
        designScorePercent = try container.decodePercent(for: ["designScore", "design_score"])
        keywordScorePercent = try container.decodePercent(for: ["keywordScore", "keyword_score", "keywordsScore", "keywords_score"])
        status = try container.decodeString(for: ["status"])
        jobUrl = try container.decodeString(for: ["jobUrl", "job_url"])
        templateKey = try container.decodeString(for: ["templateKey", "template_key"])
        resumeId = try container.decodeString(for: ["resumeId", "resume_id"])
    }

    var filename: String {
        let title = [jobTitle, company]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return title.isEmpty ? "Optimized Resume" : title
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

private extension KeyedDecodingContainer where K == DynamicCodingKey {
    func decodeString(for keys: [String]) throws -> String? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try decodeIfPresent(String.self, forKey: codingKey) {
                return value
            }
            if let value = try decodeIfPresent(Int.self, forKey: codingKey) {
                return String(value)
            }
        }
        return nil
    }

    func decodePercent(for keys: [String]) throws -> Int? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try decodeIfPresent(Int.self, forKey: codingKey) {
                return normalizePercent(Double(value))
            }
            if let value = try decodeIfPresent(Double.self, forKey: codingKey) {
                return normalizePercent(value)
            }
            if let value = try decodeIfPresent(String.self, forKey: codingKey),
               let number = Double(value) {
                return normalizePercent(number)
            }
        }
        return nil
    }

    private func normalizePercent(_ value: Double) -> Int {
        let percent = value <= 1 ? value * 100 : value
        return min(100, max(0, Int(percent.rounded())))
    }
}

struct ATSScoreResult: Codable, Sendable {
    let success: Bool?
    let score: ScorePayload?
    let preview: PreviewPayload?
    let quickWins: [QuickWin]?
    let checksRemaining: Int?
    let sessionId: String?
    let error: String?

    struct ScorePayload: Codable, Sendable {
        let overall: Int?
        let timestamp: String?
    }

    struct PreviewPayload: Codable, Sendable {
        let topIssues: [ATSIssue]
        let totalIssues: Int?
        let lockedCount: Int?
    }
}

struct ATSIssue: Codable, Identifiable, Sendable {
    var id: String { "\(category ?? severity ?? "issue")-\(message ?? text ?? suggestion ?? "ats")" }
    let category: String?
    let severity: String?
    let message: String?
    let text: String?
    let suggestion: String?
}

struct QuickWin: Codable, Identifiable, Sendable {
    var id: String { "\(keyword ?? title ?? action ?? reason ?? "quick-win")" }
    let title: String?
    let action: String?
    let keyword: String?
    let impact: String?
    let reason: String?
}

struct ApplicationItem: Codable, Identifiable, Sendable {
    let id: String
    let jobTitle: String?
    let companyName: String?
    let appliedDate: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case jobTitle = "job_title"
        case companyName = "company_name"
        case appliedDate = "applied_date"
        case status
    }
}

struct CreditTransaction: Codable, Identifiable, Sendable {
    let id: String
    let delta: Int
    let reason: String
    let source: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case delta
        case reason
        case source
        case createdAt = "created_at"
    }
}

struct CreditsResponse: Codable, Sendable {
    let balance: Int
    let transactions: [CreditTransaction]
}

struct ResumeUploadResponse: Codable, Sendable {
    let success: Bool?
    let resumeId: String?
    let jobDescriptionId: String?
    let reviewId: String?
    let nextStep: String?
    let matchScore: Int?
    let keyImprovements: [String]?
    let missingKeywords: [String]?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success
        case resumeId
        case jobDescriptionId
        case reviewId
        case nextStep
        case matchScore
        case keyImprovements
        case missingKeywords
        case error
    }
}

struct TailorRequest: Codable, Sendable {
    let resumeId: String
    let jobDescriptionId: String
}

struct TailorResponse: Codable, Sendable {
    let reviewId: String?
    let nextStep: String?
    let error: String?
}

struct IAPVerifyResponse: Codable, Sendable {
    let success: Bool?
    let creditsGranted: Int?
    let balance: Int?
    let error: String?
}

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let userId: String
    let email: String?
}
