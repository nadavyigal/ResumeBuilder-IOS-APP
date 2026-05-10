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
    let subscores: ATSSubScores?
    let subscoresOriginal: ATSSubScores?
    let suggestions: [ATSAuthSuggestion]?
    let authQuickWins: [ATSAuthQuickWinSuggestion]?

    init(
        atsScoreOriginal: Int,
        atsScoreOptimized: Int,
        confidence: Double? = nil,
        subscores: ATSSubScores? = nil,
        subscoresOriginal: ATSSubScores? = nil,
        suggestions: [ATSAuthSuggestion]? = nil,
        authQuickWins: [ATSAuthQuickWinSuggestion]? = nil
    ) {
        self.atsScoreOriginal = atsScoreOriginal
        self.atsScoreOptimized = atsScoreOptimized
        self.confidence = confidence
        self.subscores = subscores
        self.subscoresOriginal = subscoresOriginal
        self.suggestions = suggestions
        self.authQuickWins = authQuickWins
    }

    private enum CodingKeys: String, CodingKey {
        case atsScoreOriginal  = "ats_score_original"
        case atsScoreOptimized = "ats_score_optimized"
        case confidence
        case subscores
        case subscoresOriginal = "subscores_original"
        case suggestions
        case authQuickWins = "quick_wins"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func decodeFlexibleInt(for key: CodingKeys) -> Int? {
            if let value = try? c.decode(Int.self, forKey: key) {
                return value
            }
            if let value = try? c.decode(Double.self, forKey: key) {
                let scaled = value <= 1 ? value * 100 : value
                return Int(scaled.rounded())
            }
            return nil
        }
        guard
            let orig = decodeFlexibleInt(for: .atsScoreOriginal),
            let opt = decodeFlexibleInt(for: .atsScoreOptimized)
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing ATS score fields"))
        }
        self.atsScoreOriginal = orig
        self.atsScoreOptimized = opt
        self.confidence = try? c.decode(Double.self, forKey: .confidence)
        self.subscores = try c.decodeIfPresent(ATSSubScores.self, forKey: .subscores)
        self.subscoresOriginal = try c.decodeIfPresent(ATSSubScores.self, forKey: .subscoresOriginal)
        self.suggestions = try c.decodeIfPresent([ATSAuthSuggestion].self, forKey: .suggestions)
        self.authQuickWins = try c.decodeIfPresent([ATSAuthQuickWinSuggestion].self, forKey: .authQuickWins)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(atsScoreOriginal, forKey: .atsScoreOriginal)
        try c.encode(atsScoreOptimized, forKey: .atsScoreOptimized)
        try c.encodeIfPresent(confidence, forKey: .confidence)
        try c.encodeIfPresent(subscores, forKey: .subscores)
        try c.encodeIfPresent(subscoresOriginal, forKey: .subscoresOriginal)
        try c.encodeIfPresent(suggestions, forKey: .suggestions)
        try c.encodeIfPresent(authQuickWins, forKey: .authQuickWins)
    }
}

/// ATS v2 engine subscores (see `src/lib/ats/types.ts` — SubScores).
struct ATSSubScores: Codable, Sendable, Equatable {
    let keyword_exact: Int?
    let keyword_phrase: Int?
    let semantic_relevance: Int?
    let title_alignment: Int?
    let metrics_presence: Int?
    let section_completeness: Int?
    let format_parseability: Int?
    let recency_fit: Int?

    enum CodingKeys: String, CodingKey {
        case keyword_exact
        case keyword_phrase
        case semantic_relevance
        case title_alignment
        case metrics_presence
        case section_completeness
        case format_parseability
        case recency_fit
    }

    init(
        keyword_exact: Int? = nil,
        keyword_phrase: Int? = nil,
        semantic_relevance: Int? = nil,
        title_alignment: Int? = nil,
        metrics_presence: Int? = nil,
        section_completeness: Int? = nil,
        format_parseability: Int? = nil,
        recency_fit: Int? = nil
    ) {
        self.keyword_exact = keyword_exact
        self.keyword_phrase = keyword_phrase
        self.semantic_relevance = semantic_relevance
        self.title_alignment = title_alignment
        self.metrics_presence = metrics_presence
        self.section_completeness = section_completeness
        self.format_parseability = format_parseability
        self.recency_fit = recency_fit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyword_exact = Self.decodeFlexibleInt(container: c, key: .keyword_exact)
        keyword_phrase = Self.decodeFlexibleInt(container: c, key: .keyword_phrase)
        semantic_relevance = Self.decodeFlexibleInt(container: c, key: .semantic_relevance)
        title_alignment = Self.decodeFlexibleInt(container: c, key: .title_alignment)
        metrics_presence = Self.decodeFlexibleInt(container: c, key: .metrics_presence)
        section_completeness = Self.decodeFlexibleInt(container: c, key: .section_completeness)
        format_parseability = Self.decodeFlexibleInt(container: c, key: .format_parseability)
        recency_fit = Self.decodeFlexibleInt(container: c, key: .recency_fit)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(keyword_exact, forKey: .keyword_exact)
        try c.encodeIfPresent(keyword_phrase, forKey: .keyword_phrase)
        try c.encodeIfPresent(semantic_relevance, forKey: .semantic_relevance)
        try c.encodeIfPresent(title_alignment, forKey: .title_alignment)
        try c.encodeIfPresent(metrics_presence, forKey: .metrics_presence)
        try c.encodeIfPresent(section_completeness, forKey: .section_completeness)
        try c.encodeIfPresent(format_parseability, forKey: .format_parseability)
        try c.encodeIfPresent(recency_fit, forKey: .recency_fit)
    }

    private static func decodeFlexibleInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int(value.rounded())
        }
        return nil
    }
}

struct ATSAuthSuggestion: Codable, Identifiable, Sendable {
    let id: String
    let text: String?
    let category: String?
    let quickWin: Bool?
    let estimatedGain: Int?

    init(id: String, text: String?, category: String?, quickWin: Bool?, estimatedGain: Int?) {
        self.id = id
        self.text = text
        self.category = category
        self.quickWin = quickWin
        self.estimatedGain = estimatedGain
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case category
        case quickWin = "quick_win"
        case estimatedGain = "estimated_gain"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        text = try c.decodeIfPresent(String.self, forKey: .text)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        quickWin = try c.decodeIfPresent(Bool.self, forKey: .quickWin)
        if let ig = try? c.decode(Int.self, forKey: .estimatedGain) {
            estimatedGain = ig
        } else if let d = try? c.decode(Double.self, forKey: .estimatedGain) {
            estimatedGain = Int(d.rounded())
        } else {
            estimatedGain = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(quickWin, forKey: .quickWin)
        try c.encodeIfPresent(estimatedGain, forKey: .estimatedGain)
    }
}

struct ATSAuthQuickWinSuggestion: Codable, Identifiable, Sendable {
    let id: String
    let originalText: String?
    let optimizedText: String?
    let estimatedImpact: Int?
    let rationale: String?
    let improvementType: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case originalText = "original_text"
        case optimizedText = "optimized_text"
        case estimatedImpact = "estimated_impact"
        case rationale
        case improvementType = "improvement_type"
    }
}

/// POST /api/ats/rescan — client uses nested `scores` for headline ATS refresh.
struct ATSRescanResponse: Decodable, Sendable {
    let success: Bool?
    let optimizedScore: Int?
    let originalScore: Int?

    private enum CodingKeys: String, CodingKey {
        case success
        case scores
    }

    private struct FlexibleScores: Decodable, Sendable {
        let original: LossyCodingInt?
        let optimized: LossyCodingInt?
    }

    /// Decodes ints or fractional numbers (`0.82` scaled by API variants).
    private struct LossyCodingInt: Decodable, Sendable {
        let value: Int

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) {
                value = i
            } else if let d = try? c.decode(Double.self) {
                let scaled = d <= 1 ? d * 100 : d
                value = Int(scaled.rounded())
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode ATS score fraction")
            }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success)
        if let nested = try c.decodeIfPresent(FlexibleScores.self, forKey: .scores) {
            originalScore = nested.original?.value
            optimizedScore = nested.optimized?.value
        } else {
            originalScore = nil
            optimizedScore = nil
        }
    }

    init(success: Bool?, optimizedScore: Int?, originalScore: Int?) {
        self.success = success
        self.optimizedScore = optimizedScore
        self.originalScore = originalScore
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
