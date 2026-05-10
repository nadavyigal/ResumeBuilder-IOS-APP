import Foundation

/// High-level ATS + metrics snapshot produced from `/api/ats/score` (and surfaced in Improve/Home).
struct ResumeAnalysis: Sendable {
    let overall: Int
    let ats: Int
    let content: Int
    let design: Int
    let missingKeywords: [String]
    /// ATS v2 subscores when the backend returns them (`subscores`).
    let subscores: ATSSubScores?
    let subscoresOriginal: ATSSubScores?
    let suggestions: [ATSAuthSuggestion]
    let authQuickWins: [ATSAuthQuickWinSuggestion]
    /// Dashboard-only gauge for keyword alignment when `subscores` is missing.
    let keywordAlignmentPercentFallback: Int?

    init(
        overall: Int,
        ats: Int,
        content: Int,
        design: Int,
        missingKeywords: [String],
        subscores: ATSSubScores? = nil,
        subscoresOriginal: ATSSubScores? = nil,
        suggestions: [ATSAuthSuggestion] = [],
        authQuickWins: [ATSAuthQuickWinSuggestion] = [],
        keywordAlignmentPercentFallback: Int? = nil
    ) {
        self.overall = overall
        self.ats = ats
        self.content = content
        self.design = design
        self.missingKeywords = missingKeywords
        self.subscores = subscores
        self.subscoresOriginal = subscoresOriginal
        self.suggestions = suggestions
        self.authQuickWins = authQuickWins
        self.keywordAlignmentPercentFallback = keywordAlignmentPercentFallback
    }

    func withUpdatedScores(overall: Int, ats: Int) -> ResumeAnalysis {
        ResumeAnalysis(
            overall: overall,
            ats: ats,
            content: content,
            design: design,
            missingKeywords: missingKeywords,
            subscores: subscores,
            subscoresOriginal: subscoresOriginal,
            suggestions: suggestions,
            authQuickWins: authQuickWins,
            keywordAlignmentPercentFallback: keywordAlignmentPercentFallback
        )
    }

    /// Compact dashboard-style snapshot (no ATS v2 subscores).
    static func dashboard(
        overall: Int,
        keywordScore: Int?,
        content: Int?,
        design: Int?
    ) -> ResumeAnalysis {
        let k = keywordScore ?? overall
        let c = content ?? overall
        let d = design ?? overall
        return ResumeAnalysis(
            overall: overall,
            ats: overall,
            content: c,
            design: d,
            missingKeywords: [],
            subscores: nil,
            subscoresOriginal: nil,
            suggestions: [],
            authQuickWins: [],
            keywordAlignmentPercentFallback: k
        )
    }

    static let empty = ResumeAnalysis(
        overall: 0,
        ats: 0,
        content: 0,
        design: 0,
        missingKeywords: []
    )
}

extension ATSSubScores {
    /// Stable average ignoring nil components.
    static func integerAverage(of values: [Int?]) -> Int? {
        let nums = values.compactMap { $0 }
        guard !nums.isEmpty else { return nil }
        return Int((Double(nums.reduce(0, +)) / Double(nums.count)).rounded())
    }

    /// Four UI pillars aligned with the web compact breakdown (derived from ATS v2 subscores).
    func pillarScores(forOriginal original: ATSSubScores?) -> ATSFourPillarSnapshot {
        let keyword = Self.integerAverage(of: [keyword_exact, keyword_phrase, semantic_relevance]) ?? 0
        let content = Self.integerAverage(of: [title_alignment, metrics_presence]) ?? 0
        let format = Self.integerAverage(of: [format_parseability, section_completeness]) ?? 0
        let design = recency_fit ?? Self.integerAverage(of: [semantic_relevance, keyword_phrase]) ?? 0

        guard let original else {
            return ATSFourPillarSnapshot(
                rows: ATSFourPillarSnapshot.pillarRows(
                    keywordAlignment: keyword,
                    contentQuality: content,
                    formatAndStructure: format,
                    design: design,
                    deltas: nil
                )
            )
        }
        let ok = Self.integerAverage(of: [original.keyword_exact, original.keyword_phrase, original.semantic_relevance]) ?? keyword
        let oc = Self.integerAverage(of: [original.title_alignment, original.metrics_presence]) ?? content
        let of = Self.integerAverage(of: [original.format_parseability, original.section_completeness]) ?? format
        let od = original.recency_fit ?? Self.integerAverage(of: [original.semantic_relevance, original.keyword_phrase]) ?? design
        let deltas = (keyword - ok, content - oc, format - of, design - od)
        return ATSFourPillarSnapshot(
            rows: ATSFourPillarSnapshot.pillarRows(
                keywordAlignment: keyword,
                contentQuality: content,
                formatAndStructure: format,
                design: design,
                deltas: deltas
            )
        )
    }
}

struct ATSFourPillarSnapshot: Sendable {
    struct Row: Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String
        let value: Int
        let deltaFromOriginal: Int?
        let iconName: String

        /// Clamped percentage for gauges.
        var displayValue: Int { min(100, max(0, value)) }
    }

    let rows: [Row]

    static func pillarRows(
        keywordAlignment keyword: Int,
        contentQuality content: Int,
        formatAndStructure format: Int,
        design: Int,
        deltas: (Int, Int, Int, Int)?
    ) -> [Row] {
        let d0 = deltas?.0
        let d1 = deltas?.1
        let d2 = deltas?.2
        let d3 = deltas?.3
        return [
            Row(
                id: "keyword_alignment",
                title: "Keyword Alignment",
                subtitle: "Exact phrases, wording & semantic match to the JD",
                value: keyword,
                deltaFromOriginal: d0,
                iconName: "key.horizontal.fill"
            ),
            Row(
                id: "content_quality",
                title: "Content Quality",
                subtitle: "Title fit, accomplishments & measurable impact",
                value: content,
                deltaFromOriginal: d1,
                iconName: "text.quote"
            ),
            Row(
                id: "format_structure",
                title: "Format & Structure",
                subtitle: "Section coverage & ATS-parseable layout",
                value: format,
                deltaFromOriginal: d2,
                iconName: "rectangle.split.3x3.fill"
            ),
            Row(
                id: "design_signal",
                title: "Design",
                subtitle: "Recency & professional timeline alignment",
                value: design,
                deltaFromOriginal: d3,
                iconName: "timeline.selection"
            ),
        ]
    }

    /// When ATS v2 subscores are unavailable, approximate from coarse dashboard metrics.
    static func approximate(from analysis: ResumeAnalysis) -> ATSFourPillarSnapshot {
        let keywordBase = analysis.keywordAlignmentPercentFallback ?? analysis.ats
        let kw = clampPercent(keywordBase)
        let c = clampPercent(analysis.content)
        let f = clampPercent(Int(Double(analysis.overall + analysis.ats + analysis.design) / 3.0))
        let d = clampPercent(analysis.design)
        let rows = Self.pillarRows(
            keywordAlignment: kw,
            contentQuality: c,
            formatAndStructure: f,
            design: d,
            deltas: nil
        )
        return ATSFourPillarSnapshot(rows: rows)
    }

    private static func clampPercent(_ v: Int) -> Int { min(100, max(0, v)) }
}

extension ResumeAnalysis {
    func atsFourPillarSnapshot() -> ATSFourPillarSnapshot {
        if let sub = subscores {
            return sub.pillarScores(forOriginal: subscoresOriginal)
        }
        return ATSFourPillarSnapshot.approximate(from: self)
    }

    func scoreColorBucket(forPercent value: Int) -> ScoreColorBucket {
        switch value {
        case 75...100: return .high
        case 55..<75: return .medium
        default: return .low
        }
    }
}

enum ScoreColorBucket: Sendable {
    case high, medium, low
}

struct ResumeImprovement: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let impact: String   // "high" | "medium" | "low"
    var action: String?

    var impactLevel: ImpactLevel {
        switch impact.lowercased() {
        case "high":   return .high
        case "medium": return .medium
        default:       return .low
        }
    }
}
