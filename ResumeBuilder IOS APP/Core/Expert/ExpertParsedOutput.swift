import Foundation

struct ExpertSummaryOption: Sendable, Equatable, Identifiable {
    let id: Int
    let style: String
    let summary: String
}

struct ExpertBulletRewrite: Sendable, Equatable, Identifiable {
    let id: Int
    let originalBullet: String
    let optimizedBullet: String
    let impact: String?
    let missingMetrics: [String]
}

struct ExpertATSReport: Sendable, Equatable {
    let score: Double?
    let keywordPlacements: [String]
    let recommendedKeywordsToAdd: [String]
    let missingKeywords: [String]
}

struct ExpertCoverLetterVariant: Sendable, Equatable, Identifiable {
    let id: Int
    let tone: String
    let body: String
}

struct ExpertScreeningAnswer: Sendable, Equatable, Identifiable {
    let id: Int
    let question: String
    let answer: String
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
