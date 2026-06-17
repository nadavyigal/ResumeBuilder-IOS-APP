import Foundation

struct ResumeDiagnosis: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let matchScore: Int
    let potentialScore: Int?
    let scoreNote: String
    let topGaps: [ResumeGap]
    let missingKeywords: [ResumeKeyword]
    let recruiterReview: RecruiterReview
    let beforeAfter: [BulletRewrite]
    let confidenceChecklist: [ConfidenceItem]

    init(
        id: UUID = UUID(),
        matchScore: Int,
        potentialScore: Int?,
        scoreNote: String,
        topGaps: [ResumeGap],
        missingKeywords: [ResumeKeyword],
        recruiterReview: RecruiterReview,
        beforeAfter: [BulletRewrite],
        confidenceChecklist: [ConfidenceItem]
    ) {
        self.id = id
        self.matchScore = Self.clampPercent(matchScore)
        self.potentialScore = potentialScore.map(Self.clampPercent)
        self.scoreNote = scoreNote
        self.topGaps = topGaps
        self.missingKeywords = missingKeywords
        self.recruiterReview = recruiterReview
        self.beforeAfter = beforeAfter
        self.confidenceChecklist = confidenceChecklist
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        let matchScore =
            try c.decodeIfPresent(Int.self, forKey: .matchScore)
            ?? c.decodeIfPresent(Int.self, forKey: .matchScoreSnake)
            ?? 0
        let potentialScore =
            try c.decodeIfPresent(Int.self, forKey: .potentialScore)
            ?? c.decodeIfPresent(Int.self, forKey: .potentialScoreSnake)
        let scoreNote =
            try c.decodeIfPresent(String.self, forKey: .scoreNote)
            ?? c.decodeIfPresent(String.self, forKey: .scoreNoteSnake)
            ?? NSLocalizedString("Estimated match guidance based on the target job, not a hiring guarantee.", comment: "")
        let topGaps =
            try c.decodeIfPresent([ResumeGap].self, forKey: .topGaps)
            ?? c.decodeIfPresent([ResumeGap].self, forKey: .topGapsSnake)
            ?? []
        let missingKeywords =
            try c.decodeIfPresent([ResumeKeyword].self, forKey: .missingKeywords)
            ?? c.decodeIfPresent([ResumeKeyword].self, forKey: .missingKeywordsSnake)
            ?? []
        let recruiterReview =
            try c.decodeIfPresent(RecruiterReview.self, forKey: .recruiterReview)
            ?? c.decodeIfPresent(RecruiterReview.self, forKey: .recruiterReviewSnake)
            ?? RecruiterReview(
                impression: NSLocalizedString("A recruiter may see relevant experience, but the resume needs sharper targeting.", comment: ""),
                strengths: [],
                concerns: [],
                nextFix: NSLocalizedString("Review the target job and tighten the summary.", comment: "")
            )
        let beforeAfter =
            try c.decodeIfPresent([BulletRewrite].self, forKey: .beforeAfter)
            ?? c.decodeIfPresent([BulletRewrite].self, forKey: .beforeAfterSnake)
            ?? []
        let confidenceChecklist =
            try c.decodeIfPresent([ConfidenceItem].self, forKey: .confidenceChecklist)
            ?? c.decodeIfPresent([ConfidenceItem].self, forKey: .confidenceChecklistSnake)
            ?? []

        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            matchScore: matchScore,
            potentialScore: potentialScore,
            scoreNote: scoreNote,
            topGaps: topGaps,
            missingKeywords: missingKeywords,
            recruiterReview: recruiterReview,
            beforeAfter: beforeAfter,
            confidenceChecklist: confidenceChecklist
        )
    }

    private enum DecodingKeys: String, CodingKey {
        case id
        case matchScore
        case matchScoreSnake = "match_score"
        case potentialScore
        case potentialScoreSnake = "potential_score"
        case scoreNote
        case scoreNoteSnake = "score_note"
        case topGaps
        case topGapsSnake = "top_gaps"
        case missingKeywords
        case missingKeywordsSnake = "missing_keywords"
        case recruiterReview
        case recruiterReviewSnake = "recruiter_review"
        case beforeAfter
        case beforeAfterSnake = "before_after"
        case confidenceChecklist
        case confidenceChecklistSnake = "confidence_checklist"
    }

    var matchScoreLabel: String {
        NSLocalizedString("Estimated match guidance, not a guarantee.", comment: "")
    }

    var groupedKeywords: [(importance: KeywordImportance, keywords: [ResumeKeyword])] {
        KeywordImportance.allCases.compactMap { importance in
            let values = missingKeywords.filter { $0.importance == importance }
            return values.isEmpty ? nil : (importance, values)
        }
    }

    static func sample() -> ResumeDiagnosis {
        ResumeDiagnosis(
            matchScore: 54,
            potentialScore: 82,
            scoreNote: NSLocalizedString("Estimated match guidance based on the target job, not a hiring guarantee.", comment: ""),
            topGaps: [
                ResumeGap(title: "Missing product analytics keywords", explanation: "The job emphasizes analytics ownership, but the resume mostly describes reporting.", severity: .high),
                ResumeGap(title: "Achievements are too generic", explanation: "Several bullets describe responsibilities without business outcomes.", severity: .medium),
                ResumeGap(title: "Target role is unclear", explanation: "The summary should point more directly at the role being pursued.", severity: .medium),
            ],
            missingKeywords: [
                ResumeKeyword(keyword: "Product analytics", importance: .high, reason: "Repeated in the job description"),
                ResumeKeyword(keyword: "Retention", importance: .medium, reason: "Useful context for business impact"),
                ResumeKeyword(keyword: "Experimentation", importance: .low, reason: "Nice-to-have signal if truthful"),
            ],
            recruiterReview: RecruiterReview(
                impression: "Strong operations background, but the resume does not yet prove product ownership.",
                strengths: ["Finance", "Stakeholder work", "Process improvement"],
                concerns: ["Missing metrics", "Weak role targeting"],
                nextFix: NSLocalizedString("Rewrite the summary around the target job.", comment: "")
            ),
            beforeAfter: [
                BulletRewrite(
                    before: "Responsible for reports",
                    after: "Built weekly reporting workflows that helped leadership identify churn risks and prioritize renewal actions.",
                    explanation: "Stronger because it adds action, business context, and measurable impact."
                )
            ],
            confidenceChecklist: ConfidenceItem.defaultChecklist(matchScore: 82, hasKeywords: true, hasRewrite: true)
        )
    }

    private static func clampPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

struct ResumeGap: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let explanation: String
    let severity: GapSeverity

    init(id: UUID = UUID(), title: String, explanation: String, severity: GapSeverity) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.severity = severity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? NSLocalizedString("Resume gap", comment: ""),
            explanation: try c.decodeIfPresent(String.self, forKey: .explanation) ?? NSLocalizedString("Review this area before submitting.", comment: ""),
            severity: GapSeverity(rawValueOrDefault: try c.decodeIfPresent(String.self, forKey: .severity))
        )
    }

    private enum DecodingKeys: String, CodingKey {
        case id
        case title
        case explanation
        case severity
    }
}

enum GapSeverity: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low

    init(rawValueOrDefault value: String?) {
        switch value?.lowercased() {
        case "high", "critical": self = .high
        case "low", "nice_to_have", "nice-to-have": self = .low
        default: self = .medium
        }
    }

    var label: String {
        switch self {
        case .high: return NSLocalizedString("High", comment: "")
        case .medium: return NSLocalizedString("Medium", comment: "")
        case .low: return NSLocalizedString("Low", comment: "")
        }
    }
}

struct ResumeKeyword: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let keyword: String
    let importance: KeywordImportance
    let reason: String?

    init(id: UUID = UUID(), keyword: String, importance: KeywordImportance, reason: String? = nil) {
        self.id = id
        self.keyword = keyword
        self.importance = importance
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            keyword: try c.decodeIfPresent(String.self, forKey: .keyword) ?? "Target keyword",
            importance: KeywordImportance(rawValueOrDefault: try c.decodeIfPresent(String.self, forKey: .importance)),
            reason: try c.decodeIfPresent(String.self, forKey: .reason)
        )
    }

    private enum DecodingKeys: String, CodingKey {
        case id
        case keyword
        case importance
        case reason
    }
}

enum KeywordImportance: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low

    init(rawValueOrDefault value: String?) {
        switch value?.lowercased() {
        case "high", "critical", "required": self = .high
        case "low", "nice_to_have", "nice-to-have": self = .low
        default: self = .medium
        }
    }

    var label: String {
        switch self {
        case .high: return NSLocalizedString("High priority", comment: "")
        case .medium: return NSLocalizedString("Medium priority", comment: "")
        case .low: return NSLocalizedString("Nice to have", comment: "")
        }
    }
}

struct RecruiterReview: Codable, Equatable, Sendable {
    let impression: String
    let strengths: [String]
    let concerns: [String]
    let nextFix: String

    init(impression: String, strengths: [String], concerns: [String], nextFix: String) {
        self.impression = impression
        self.strengths = strengths
        self.concerns = concerns
        self.nextFix = nextFix
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        let nextFix =
            try c.decodeIfPresent(String.self, forKey: .nextFix)
            ?? c.decodeIfPresent(String.self, forKey: .nextFixSnake)
            ?? NSLocalizedString("Rewrite the summary around the target job.", comment: "")
        self.init(
            impression: try c.decodeIfPresent(String.self, forKey: .impression) ?? "A recruiter may need clearer evidence for the target role.",
            strengths: try c.decodeIfPresent([String].self, forKey: .strengths) ?? [],
            concerns: try c.decodeIfPresent([String].self, forKey: .concerns) ?? [],
            nextFix: nextFix
        )
    }

    private enum DecodingKeys: String, CodingKey {
        case impression
        case strengths
        case concerns
        case nextFix
        case nextFixSnake = "next_fix"
    }
}

struct BulletRewrite: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let before: String?
    let after: String
    let explanation: String

    init(id: UUID = UUID(), before: String?, after: String, explanation: String) {
        self.id = id
        self.before = before?.nilIfBlank
        self.after = after
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        let before =
            try c.decodeIfPresent(String.self, forKey: .before)
            ?? c.decodeIfPresent(String.self, forKey: .original)
            ?? c.decodeIfPresent(String.self, forKey: .originalBullet)
            ?? c.decodeIfPresent(String.self, forKey: .originalBulletSnake)
        let after =
            try c.decodeIfPresent(String.self, forKey: .after)
            ?? c.decodeIfPresent(String.self, forKey: .improved)
            ?? c.decodeIfPresent(String.self, forKey: .improvedBullet)
            ?? c.decodeIfPresent(String.self, forKey: .improvedBulletSnake)
            ?? ""
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            before: before,
            after: after,
            explanation: try c.decodeIfPresent(String.self, forKey: .explanation) ?? "Review every fact before submitting."
        )
    }

    var hasOriginalBullet: Bool {
        before?.isEmpty == false
    }

    private enum DecodingKeys: String, CodingKey {
        case id
        case before
        case original
        case originalBullet
        case originalBulletSnake = "original_bullet"
        case after
        case improved
        case improvedBullet
        case improvedBulletSnake = "improved_bullet"
        case explanation
    }
}

struct ConfidenceItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let isComplete: Bool
    let explanation: String?

    init(id: UUID = UUID(), title: String, isComplete: Bool, explanation: String? = nil) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DecodingKeys.self)
        let isComplete =
            try c.decodeIfPresent(Bool.self, forKey: .isComplete)
            ?? c.decodeIfPresent(Bool.self, forKey: .isCompleteSnake)
            ?? false
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "Resume readiness item",
            isComplete: isComplete,
            explanation: try c.decodeIfPresent(String.self, forKey: .explanation)
        )
    }

    private enum DecodingKeys: String, CodingKey {
        case id
        case title
        case isComplete
        case isCompleteSnake = "is_complete"
        case explanation
    }

    static func defaultChecklist(matchScore: Int, hasKeywords: Bool, hasRewrite: Bool) -> [ConfidenceItem] {
        [
            ConfidenceItem(
                title: NSLocalizedString("Includes priority keywords", comment: ""),
                isComplete: hasKeywords,
                explanation: hasKeywords ? NSLocalizedString("More aligned with the target role wording.", comment: "") : NSLocalizedString("Add truthful priority terms from the job post.", comment: "")
            ),
            ConfidenceItem(
                title: NSLocalizedString("Clearer summary", comment: ""),
                isComplete: matchScore >= 60,
                explanation: NSLocalizedString("Positioning is easier to scan in the first few seconds.", comment: "")
            ),
            ConfidenceItem(
                title: NSLocalizedString("More measurable achievements", comment: ""),
                isComplete: hasRewrite,
                explanation: NSLocalizedString("Stronger bullets connect actions to context and impact.", comment: "")
            ),
            ConfidenceItem(
                title: NSLocalizedString("Better ATS formatting", comment: ""),
                isComplete: true,
                explanation: NSLocalizedString("Uses parseable sections and direct role language.", comment: "")
            ),
            ConfidenceItem(
                title: NSLocalizedString("Tailored to target role", comment: ""),
                isComplete: matchScore >= 55,
                explanation: NSLocalizedString("More aligned, not guaranteed to pass any ATS.", comment: "")
            ),
        ]
    }
}

enum ResumeDiagnosisMapper {
    static func make(
        backendDiagnosis: ResumeDiagnosis? = nil,
        matchScore: Int?,
        potentialScore: Int?,
        blockers: [ATSOptimizationBlocker],
        sections: [OptimizedResumeSection],
        jobTitle: String?,
        company: String?
    ) -> ResumeDiagnosis {
        let derived = Self.derived(
            matchScore: matchScore,
            potentialScore: potentialScore,
            blockers: blockers,
            sections: sections,
            jobTitle: jobTitle,
            company: company
        )

        if let backendDiagnosis {
            return Self.merge(backendDiagnosis, with: derived, hasLiveBlockers: !blockers.isEmpty, hasLiveSections: !sections.isEmpty)
        }

        return derived
    }

    private static func derived(
        matchScore: Int?,
        potentialScore: Int?,
        blockers: [ATSOptimizationBlocker],
        sections: [OptimizedResumeSection],
        jobTitle: String?,
        company: String?
    ) -> ResumeDiagnosis {
        let currentScore = matchScore ?? potentialScore ?? 0
        let optimizedScore = potentialScore
        let gaps = Self.gaps(from: blockers)
        let keywords = Self.keywords(from: blockers)
        let rewrite = Self.rewrite(from: sections)
        let review = Self.recruiterReview(
            currentScore: currentScore,
            blockers: blockers,
            sections: sections,
            jobTitle: jobTitle,
            company: company
        )

        return ResumeDiagnosis(
            matchScore: currentScore,
            potentialScore: optimizedScore,
            scoreNote: NSLocalizedString("Estimated match guidance based on the target job, not a hiring guarantee.", comment: ""),
            topGaps: gaps,
            missingKeywords: keywords,
            recruiterReview: review,
            beforeAfter: rewrite.map { [$0] } ?? [],
            confidenceChecklist: ConfidenceItem.defaultChecklist(
                matchScore: optimizedScore ?? currentScore,
                hasKeywords: !keywords.isEmpty,
                hasRewrite: rewrite != nil
            )
        )
    }

    private static func merge(
        _ backend: ResumeDiagnosis,
        with derived: ResumeDiagnosis,
        hasLiveBlockers: Bool,
        hasLiveSections: Bool
    ) -> ResumeDiagnosis {
        let mergedKeywords = hasLiveBlockers && !derived.missingKeywords.isEmpty ? derived.missingKeywords : backend.missingKeywords
        let mergedRewrite = hasLiveSections && !derived.beforeAfter.isEmpty ? derived.beforeAfter : backend.beforeAfter
        let mergedScore = derived.matchScore > 0 ? derived.matchScore : backend.matchScore
        let mergedPotential = derived.potentialScore ?? backend.potentialScore

        return ResumeDiagnosis(
            id: backend.id,
            matchScore: mergedScore,
            potentialScore: mergedPotential,
            scoreNote: backend.scoreNote.isEmpty ? derived.scoreNote : backend.scoreNote,
            topGaps: hasLiveBlockers ? derived.topGaps : backend.topGaps,
            missingKeywords: mergedKeywords,
            recruiterReview: hasLiveBlockers || hasLiveSections ? derived.recruiterReview : backend.recruiterReview,
            beforeAfter: mergedRewrite,
            confidenceChecklist: ConfidenceItem.defaultChecklist(
                matchScore: mergedPotential ?? mergedScore,
                hasKeywords: !mergedKeywords.isEmpty,
                hasRewrite: !mergedRewrite.isEmpty
            )
        )
    }

    static func make(from detail: OptimizationDetailDTO) -> ResumeDiagnosis {
        make(
            backendDiagnosis: detail.diagnosis,
            matchScore: detail.atsScoreBefore,
            potentialScore: detail.atsScoreAfter,
            blockers: detail.atsBlockers,
            sections: detail.sections,
            jobTitle: detail.jobTitle,
            company: detail.company
        )
    }

    private static func gaps(from blockers: [ATSOptimizationBlocker]) -> [ResumeGap] {
        let mapped = blockers.prefix(3).map { blocker in
            ResumeGap(
                title: blocker.title,
                explanation: blocker.suggestedAction?.nilIfBlank ?? blocker.detail?.nilIfBlank ?? NSLocalizedString("Review this area before submitting.", comment: ""),
                severity: GapSeverity(rawValueOrDefault: blocker.severity)
            )
        }
        if !mapped.isEmpty { return mapped }
        return [
            ResumeGap(
                title: NSLocalizedString("Target role alignment needs review", comment: ""),
                explanation: NSLocalizedString("Compare the summary, skills, and strongest bullets against the job description.", comment: ""),
                severity: .medium
            ),
            ResumeGap(
                title: NSLocalizedString("Measurable outcomes may be light", comment: ""),
                explanation: NSLocalizedString("Recruiters scan for scope, numbers, and business context.", comment: ""),
                severity: .medium
            ),
            ResumeGap(
                title: NSLocalizedString("Keyword coverage is not confirmed", comment: ""),
                explanation: NSLocalizedString("Add only truthful terms that appear in the target job.", comment: ""),
                severity: .low
            ),
        ]
    }

    private static func keywords(from blockers: [ATSOptimizationBlocker]) -> [ResumeKeyword] {
        var seen = Set<String>()
        return blockers
            .filter { blocker in
                let text = [blocker.category, blocker.title, blocker.detail, blocker.suggestedAction]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .lowercased()
                return text.contains("keyword") || text.contains("missing") || text.contains("required")
            }
            .compactMap { blocker -> ResumeKeyword? in
                guard let keyword = keywordCandidate(from: blocker).nilIfBlank else { return nil }
                let key = keyword.lowercased()
                guard seen.insert(key).inserted else { return nil }
                return ResumeKeyword(
                    keyword: keyword,
                    importance: KeywordImportance(rawValueOrDefault: blocker.severity),
                    reason: blocker.suggestedAction?.nilIfBlank ?? blocker.detail?.nilIfBlank
                )
            }
    }

    private static func keywordCandidate(from blocker: ATSOptimizationBlocker) -> String {
        let raw = blocker.title
            .replacingOccurrences(of: #"(?i)\bmissing\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\brequired\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bkeywords?\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if raw.isEmpty {
            return blocker.category.capitalized
        }
        return String(raw.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func recruiterReview(
        currentScore: Int,
        blockers: [ATSOptimizationBlocker],
        sections: [OptimizedResumeSection],
        jobTitle: String?,
        company: String?
    ) -> RecruiterReview {
        let target = jobTitle?.nilIfBlank ?? NSLocalizedString("the target role", comment: "")
        let concernTitles = blockers.prefix(2).map(\.title)
        let hasExperience = sections.contains { $0.type == .experience && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasSkills = sections.contains { $0.type == .skills && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let companyText = company?.nilIfBlank.map { String(format: NSLocalizedString(" at %@", comment: ""), $0) } ?? ""

        let impression: String
        if currentScore >= 75 {
            impression = String(format: NSLocalizedString("A recruiter may see a reasonably strong fit for %@, with a few details still worth tightening.", comment: ""), target + companyText)
        } else {
            impression = String(format: NSLocalizedString("A recruiter may see relevant experience, but the resume needs sharper proof for %@.", comment: ""), target + companyText)
        }

        return RecruiterReview(
            impression: impression,
            strengths: [
                hasExperience ? NSLocalizedString("Experience section is present", comment: "") : nil,
                hasSkills ? NSLocalizedString("Skills section is present", comment: "") : nil,
                currentScore >= 60 ? NSLocalizedString("Some role alignment is visible", comment: "") : nil,
            ].compactMap { $0 }.ifEmpty([NSLocalizedString("Relevant background", comment: ""), NSLocalizedString("Transferable experience", comment: "")]),
            concerns: concernTitles.ifEmpty(["Missing metrics", NSLocalizedString("Role targeting needs sharpening", comment: "")]),
            nextFix: blockers.first?.suggestedAction?.nilIfBlank ?? NSLocalizedString("Rewrite the summary and strongest bullets around the target job.", comment: "")
        )
    }

    private static func rewrite(from sections: [OptimizedResumeSection]) -> BulletRewrite? {
        let candidate = sections.first { $0.type == .experience && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? sections.first { $0.type == .summary && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let line = candidate?.body
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) })
            .first(where: { !$0.isEmpty })
        else { return nil }

        return BulletRewrite(
            before: nil,
            after: line,
            explanation: NSLocalizedString("Stronger because it uses target-role language already present in the optimized resume. Review every fact before submitting.", comment: "")
        )
    }
}

private extension Array {
    func ifEmpty(_ fallback: [Element]) -> [Element] {
        isEmpty ? fallback : self
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
