import Foundation

struct ExpertSummaryOption: Sendable, Equatable, Identifiable {
    let id: Int
    let angle: String
    let summary: String
    let rationale: String?

    var style: String { angle }
}

struct ExpertBulletRewrite: Sendable, Equatable, Identifiable {
    let id: Int
    let originalBullet: String
    let optimizedBullet: String
    let evidenceUsed: [String]
    let missingEvidenceQuestions: [String]

    var missingMetrics: [String] { missingEvidenceQuestions }
}

struct ExpertKeywordMatch: Sendable, Equatable, Identifiable {
    let id: Int
    let keyword: String
    let present: Bool?
    let suggestedPlacement: String?
    let note: String?
}

struct ExpertScoreEstimate: Sendable, Equatable {
    let before: Double?
    let after: Double?
}

struct ExpertATSReport: Sendable, Equatable {
    let score: Double?
    let scoreEstimate: ExpertScoreEstimate?
    let keywordMatches: [ExpertKeywordMatch]
    let keywordPlacements: [String]
    let recommendedKeywordsToAdd: [String]
    let missingKeywords: [String]
    let sectionHeadingCompliance: [String]
    let formatGuidance: [String]
    let acronymCoverage: [String]
}

struct ExpertCoverLetterVariant: Sendable, Equatable, Identifiable {
    let id: Int
    let angle: String
    let title: String?
    let openingParagraph: String?
    let letter: String
    let rationale: String?

    var tone: String { angle }
    var body: String { letter }
}

struct ExpertScreeningAnswer: Sendable, Equatable, Identifiable {
    let id: Int
    let question: String
    let answer: String
    let evidenceUsed: [String]
    let confidenceNote: String?
}

struct ExpertOutputParsed: Sendable, Equatable {
    let summaryOptions: [ExpertSummaryOption]
    let recommendedIndex: Int?
    let bulletRewrites: [ExpertBulletRewrite]
    let atsReport: ExpertATSReport?
    let coverLetterVariants: [ExpertCoverLetterVariant]
    let screeningAnswers: [ExpertScreeningAnswer]

    static let empty = ExpertOutputParsed(
        summaryOptions: [],
        recommendedIndex: nil,
        bulletRewrites: [],
        atsReport: nil,
        coverLetterVariants: [],
        screeningAnswers: []
    )
}
