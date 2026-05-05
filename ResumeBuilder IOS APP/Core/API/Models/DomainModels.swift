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
