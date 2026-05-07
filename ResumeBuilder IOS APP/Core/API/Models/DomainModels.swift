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
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

private struct DynamicCodingKey: CodingKey {
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

struct APIStatusResponse: Codable, Sendable {
    let success: Bool?
    let error: String?
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
    let atsScore: Int?
    let sourceURL: String?
    let optimizationId: String?
    let resumeHTMLPath: String?
    let resumeJSONPath: String?
    let optimizedResumeURL: String?
    let jobExtraction: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case id
        case jobTitle = "job_title"
        case companyName = "company_name"
        case appliedDate = "applied_date"
        case status
        case atsScore = "ats_score"
        case sourceURL = "source_url"
        case optimizationId = "optimization_id"
        case resumeHTMLPath = "resume_html_path"
        case resumeJSONPath = "resume_json_path"
        case optimizedResumeURL = "optimized_resume_url"
        case jobExtraction = "job_extraction"
    }
}

struct ApplicationsResponse: Codable, Sendable {
    let success: Bool?
    let applications: [ApplicationItem]
    let error: String?
}

struct OptimizationHistoryResponse: Codable, Sendable {
    let optimizations: [OptimizationItem]?
    let data: [OptimizationItem]?
    let items: [OptimizationItem]?
    let success: Bool?
    let error: String?

    var resolvedOptimizations: [OptimizationItem] {
        optimizations ?? data ?? items ?? []
    }
}

struct OptimizationItem: Codable, Identifiable, Sendable {
    let id: String
    let resumeId: String?
    let jobDescriptionId: String?
    let jobTitle: String?
    let company: String?
    let jobURL: String?
    let matchScore: Int?
    let status: String?
    let templateKey: String?
    let rewriteData: JSONValue?
    let createdAt: String?
    let jobDescription: OptimizationJobDescription?

    private enum CodingKeys: String, CodingKey {
        case id
        case resumeId = "resume_id"
        case jobDescriptionId = "jd_id"
        case jobTitle
        case company
        case jobURL = "jobUrl"
        case matchScore = "match_score"
        case status
        case templateKey = "template_key"
        case rewriteData = "rewrite_data"
        case createdAt = "created_at"
        case jobDescription = "job_descriptions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try Self.decodeString(from: dynamicContainer, key: "id") ?? ""
        resumeId = try Self.decodeString(from: dynamicContainer, key: "resumeId")
            ?? Self.decodeString(from: dynamicContainer, key: "resume_id")
        jobDescriptionId = try Self.decodeString(from: dynamicContainer, key: "jobDescriptionId")
            ?? Self.decodeString(from: dynamicContainer, key: "jd_id")
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        jobURL = try container.decodeIfPresent(String.self, forKey: .jobURL)
            ?? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKey("source_url"))
        matchScore = try container.decodeIfPresent(Int.self, forKey: .matchScore)
            ?? dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKey("matchScore"))
        status = try container.decodeIfPresent(String.self, forKey: .status)
        templateKey = try container.decodeIfPresent(String.self, forKey: .templateKey)
            ?? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKey("templateKey"))
        rewriteData = try container.decodeIfPresent(JSONValue.self, forKey: .rewriteData)
            ?? dynamicContainer.decodeIfPresent(JSONValue.self, forKey: DynamicCodingKey("rewriteData"))
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKey("createdAt"))
        jobDescription = try container.decodeIfPresent(OptimizationJobDescription.self, forKey: .jobDescription)
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        key: String
    ) throws -> String? {
        let codingKey = DynamicCodingKey(key)
        if let value = try? container.decodeIfPresent(String.self, forKey: codingKey) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: codingKey) {
            return String(value)
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: codingKey) {
            return String(Int(value))
        }
        return nil
    }
}

struct OptimizationJobDescription: Codable, Sendable {
    let title: String?
    let company: String?
    let sourceURL: String?

    private enum CodingKeys: String, CodingKey {
        case title
        case company
        case sourceURL = "source_url"
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
        case resumeId = "resume_id"
        case jobDescriptionId = "jobDescriptionId"
        case reviewId
        case nextStep
        case matchScore
        case keyImprovements
        case missingKeywords
        case error
    }

    init(
        success: Bool?,
        resumeId: String?,
        jobDescriptionId: String?,
        reviewId: String?,
        nextStep: String?,
        matchScore: Int?,
        keyImprovements: [String]?,
        missingKeywords: [String]?,
        error: String?
    ) {
        self.success = success
        self.resumeId = resumeId
        self.jobDescriptionId = jobDescriptionId
        self.reviewId = reviewId
        self.nextStep = nextStep
        self.matchScore = matchScore
        self.keyImprovements = keyImprovements
        self.missingKeywords = missingKeywords
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        resumeId = try container.decodeIfPresent(String.self, forKey: .resumeId)
            ?? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKey("resumeId"))
        jobDescriptionId = try container.decodeIfPresent(String.self, forKey: .jobDescriptionId)
            ?? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKey("job_description_id"))
        reviewId = try container.decodeIfPresent(String.self, forKey: .reviewId)
        nextStep = try container.decodeIfPresent(String.self, forKey: .nextStep)
        matchScore = try container.decodeIfPresent(Int.self, forKey: .matchScore)
        keyImprovements = try container.decodeIfPresent([String].self, forKey: .keyImprovements)
        missingKeywords = try container.decodeIfPresent([String].self, forKey: .missingKeywords)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

struct OptimizationReviewResponse: Codable, Sendable {
    let review: OptimizationReviewRun
    let resume: ReviewResume?
    let jobDescription: ReviewJobDescription?
}

struct OptimizationReviewRun: Codable, Sendable {
    let id: String
    let resumeId: String?
    let jobDescriptionId: String?
    let optimizedResumeJSON: JSONValue?
    let groupedChangesJSON: JSONValue?
    let atsPreviewJSON: JSONValue?
    let appliedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case resumeId = "resume_id"
        case jobDescriptionId = "jd_id"
        case optimizedResumeJSON = "optimized_resume_json"
        case groupedChangesJSON = "grouped_changes_json"
        case atsPreviewJSON = "ats_preview_json"
        case appliedAt = "applied_at"
    }
}

struct ReviewResume: Codable, Sendable {
    let filename: String?
    let rawText: String?

    private enum CodingKeys: String, CodingKey {
        case filename
        case rawText = "raw_text"
    }
}

struct ReviewJobDescription: Codable, Sendable {
    let title: String?
    let company: String?
    let sourceURL: String?
    let rawText: String?
    let cleanText: String?

    private enum CodingKeys: String, CodingKey {
        case title
        case company
        case sourceURL = "source_url"
        case rawText = "raw_text"
        case cleanText = "clean_text"
    }
}

struct ApplyReviewResponse: Codable, Sendable {
    let optimizationId: String?
    let approvedCount: Int?
    let rejectedCount: Int?
    let atsImpact: JSONValue?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case optimizationId
        case approvedCount
        case rejectedCount
        case atsImpact
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        if let stringId = try container.decodeIfPresent(String.self, forKey: .optimizationId) {
            optimizationId = stringId
        } else if let intId = try dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKey("optimizationId")) {
            optimizationId = String(intId)
        } else {
            optimizationId = nil
        }
        approvedCount = try container.decodeIfPresent(Int.self, forKey: .approvedCount)
        rejectedCount = try container.decodeIfPresent(Int.self, forKey: .rejectedCount)
        atsImpact = try container.decodeIfPresent(JSONValue.self, forKey: .atsImpact)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

struct DesignTemplatesResponse: Codable, Sendable {
    let templates: [DesignTemplate]
}

struct IAPVerifyResponse: Codable, Sendable {
    let success: Bool?
    let creditsGranted: Int?
    let balance: Int?
    let error: String?
}

struct DesignTemplate: Codable, Identifiable, Sendable {
    let id: String
    let slug: String?
    let name: String
    let description: String?
    let category: String?
    let isPremium: Bool?
    let thumbnailURL: String?
    let atsScore: Int?
    let colorScheme: JSONValue?
    let fontFamily: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case description
        case category
        case isPremium = "is_premium"
        case thumbnailURL = "thumbnail_url"
        case atsScore = "ats_score"
        case colorScheme = "color_scheme"
        case fontFamily = "font_family"
    }
}

struct ResumeSnapshot: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let matchScore: Int?
    let sections: [ResumeSection]

    init(id: String, title: String, subtitle: String, matchScore: Int?, json: JSONValue?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.matchScore = matchScore
        self.sections = ResumeSnapshot.sections(from: json)
    }

    private static func sections(from json: JSONValue?) -> [ResumeSection] {
        guard let object = json?.objectValue else { return [] }
        let preferredKeys = ["summary", "experience", "skills", "education", "projects", "certifications"]
        return preferredKeys.compactMap { key in
            guard let value = object[key] else { return nil }
            return ResumeSection(title: key.capitalized, lines: lines(from: value))
        }.filter { !$0.lines.isEmpty }
    }

    private static func lines(from value: JSONValue) -> [String] {
        switch value {
        case .string(let text):
            return [text]
        case .array(let values):
            return values.flatMap(lines(from:))
        case .object(let object):
            if let bullets = object["bullets"]?.arrayValue {
                return bullets.flatMap(lines(from:))
            }
            return object.values.flatMap(lines(from:))
        default:
            return []
        }
    }
}

struct ResumeSection: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let lines: [String]
}

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let userId: String
    let email: String?
}
