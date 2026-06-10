import Foundation

enum ExpertReportParsing {
    /// Parses all structured expert output fields from the `output` JSON.
    static func parsedOutput(from output: JSONValue) -> ExpertOutputParsed {
        guard case .object(let root) = output else { return .empty }

        let summaryOptions: [ExpertSummaryOption] = {
            guard let optVal = root["summary_options"], case .array(let opts) = optVal else { return [] }
            return opts.enumerated().compactMap { idx, val -> ExpertSummaryOption? in
                guard case .object(let o) = val else { return nil }
                let angle =
                    string(o["angle"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? string(o["style"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "Option \(idx + 1)"
                let summary = string(o["summary"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !summary.isEmpty else { return nil }
                let rationale = string(o["rationale"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                return ExpertSummaryOption(id: idx, angle: angle, summary: summary, rationale: rationale)
            }
        }()

        let recommendedIndex = intFromFlexible(root["recommended_index"])

        let bulletRewrites: [ExpertBulletRewrite] = {
            guard let brVal = root["bullet_rewrites"], case .array(let rows) = brVal else { return [] }
            return rows.enumerated().compactMap { idx, row -> ExpertBulletRewrite? in
                guard case .object(let o) = row else { return nil }
                let original = string(o["original_bullet"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let optimized = string(o["optimized_bullet"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !original.isEmpty || !optimized.isEmpty else { return nil }
                let evidenceUsed = stringArray(o["evidence_used"])
                let missingEvidenceQuestions =
                    stringArray(o["missing_evidence_questions"]).isEmpty
                    ? stringArray(o["missing_metrics"])
                    : stringArray(o["missing_evidence_questions"])
                return ExpertBulletRewrite(
                    id: idx,
                    originalBullet: original,
                    optimizedBullet: optimized,
                    evidenceUsed: evidenceUsed,
                    missingEvidenceQuestions: missingEvidenceQuestions
                )
            }
        }()

        let atsReport: ExpertATSReport? = {
            guard let atVal = root["ats_report"], case .object(let ats) = atVal else { return nil }
            let scoreEstimate: ExpertScoreEstimate? = {
                guard let value = ats["score_estimate"], case .object(let estimate) = value else { return nil }
                return ExpertScoreEstimate(before: double(estimate["before"]), after: double(estimate["after"]))
            }()
            let score = double(ats["score"]) ?? scoreEstimate?.after
            let keywordMatches = keywordMatches(from: ats["keyword_match_analysis"])
            let placements = stringArray(ats["keyword_placements"])
            let recommended = stringArray(ats["recommended_keywords_to_add"])
            let missing = stringArray(ats["missing_keywords"])
            let sectionHeadingCompliance = stringArray(ats["section_heading_compliance"])
            let formatGuidance = stringArray(ats["format_guidance"])
            let acronymCoverage = stringArray(ats["acronym_coverage"])
            guard score != nil
                || scoreEstimate != nil
                || !keywordMatches.isEmpty
                || !placements.isEmpty
                || !recommended.isEmpty
                || !missing.isEmpty
                || !sectionHeadingCompliance.isEmpty
                || !formatGuidance.isEmpty
                || !acronymCoverage.isEmpty
            else { return nil }
            return ExpertATSReport(
                score: score,
                scoreEstimate: scoreEstimate,
                keywordMatches: keywordMatches,
                keywordPlacements: placements,
                recommendedKeywordsToAdd: recommended,
                missingKeywords: missing,
                sectionHeadingCompliance: sectionHeadingCompliance,
                formatGuidance: formatGuidance,
                acronymCoverage: acronymCoverage
            )
        }()

        let coverLetterVariants: [ExpertCoverLetterVariant] = {
            guard let clVal = root["cover_letter_variants"], case .array(let variants) = clVal else { return [] }
            return variants.enumerated().compactMap { idx, val -> ExpertCoverLetterVariant? in
                guard case .object(let o) = val else { return nil }
                let angle =
                    string(o["angle"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? string(o["tone"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "Variant \(idx + 1)"
                let title = string(o["title"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                let opening = string(o["opening_paragraph"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                let letter =
                    string(o["letter"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? string(o["body"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? ""
                guard !letter.isEmpty else { return nil }
                let rationale = string(o["rationale"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                return ExpertCoverLetterVariant(
                    id: idx,
                    angle: angle,
                    title: title,
                    openingParagraph: opening,
                    letter: letter,
                    rationale: rationale
                )
            }
        }()

        let screeningAnswers: [ExpertScreeningAnswer] = {
            guard let saVal = root["screening_answers"], case .array(let answers) = saVal else { return [] }
            return answers.enumerated().compactMap { idx, val -> ExpertScreeningAnswer? in
                guard case .object(let o) = val else { return nil }
                let question = string(o["question"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let answer = string(o["answer"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !answer.isEmpty else { return nil }
                return ExpertScreeningAnswer(
                    id: idx,
                    question: question,
                    answer: answer,
                    evidenceUsed: stringArray(o["evidence_used"]),
                    confidenceNote: string(o["confidence_note"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            }
        }()

        return ExpertOutputParsed(
            summaryOptions: summaryOptions,
            recommendedIndex: recommendedIndex,
            bulletRewrites: bulletRewrites,
            atsReport: atsReport,
            coverLetterVariants: coverLetterVariants,
            screeningAnswers: screeningAnswers
        )
    }

    /// Pulls `report` from expert `output` JSON (matches web `toReportEnvelope`).
    static func displayModel(from output: JSONValue) -> ExpertReportDisplayModel? {
        guard case .object(let root) = output,
              let reportVal = root["report"] else {
            return nil
        }
        guard case .object(let r) = reportVal else { return nil }

        let headline =
            string(r["headline"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Expert report"
        let exec =
            string(r["executive_summary"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let priority = stringArray(r["priority_actions"])
        let gaps = stringArray(r["evidence_gaps"])
        let estimate: ExpertAtsImpactEstimate? = {
            guard let obj = r["ats_impact_estimate"], case .object(let im) = obj else { return nil }
            return ExpertAtsImpactEstimate(
                before: double(im["before"]),
                after: double(im["after"]),
                delta: double(im["delta"]),
                confidenceNote: string(im["confidence_note"])
            )
        }()

        return ExpertReportDisplayModel(
            headline: headline,
            executiveSummary: exec,
            priorityActions: priority,
            evidenceGaps: gaps,
            atsImpact: estimate
        )
    }

    private static func intFromFlexible(_ val: JSONValue?) -> Int? {
        guard let val else { return nil }
        if case .number(let n) = val { return Int(n.rounded()) }
        if case .string(let s) = val { return Int(s) }
        return nil
    }

    private static func string(_ v: JSONValue?) -> String? {
        guard let v else { return nil }
        if case .string(let s) = v { return s }
        if case .number(let n) = v { return String(format: "%g", n) }
        if case .bool(let b) = v { return b ? "true" : "false" }
        return nil
    }

    private static func double(_ v: JSONValue?) -> Double? {
        guard let v else { return nil }
        if case .number(let n) = v { return n }
        if case .string(let s) = v { return Double(s) }
        return nil
    }

    private static func stringArray(_ v: JSONValue?) -> [String] {
        guard let v, case .array(let rows) = v else { return [] }
        return rows.compactMap { string($0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func keywordMatches(from value: JSONValue?) -> [ExpertKeywordMatch] {
        guard let value, case .array(let rows) = value else { return [] }
        return rows.enumerated().compactMap { idx, row -> ExpertKeywordMatch? in
            guard case .object(let object) = row else { return nil }
            let keyword = string(object["keyword"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !keyword.isEmpty else { return nil }
            let present: Bool? = {
                guard let presentValue = object["present"] else { return nil }
                if case .bool(let present) = presentValue { return present }
                return nil
            }()
            return ExpertKeywordMatch(
                id: idx,
                keyword: keyword,
                present: present,
                suggestedPlacement: string(object["suggested_placement"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                note: string(object["note"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : self
    }
}
