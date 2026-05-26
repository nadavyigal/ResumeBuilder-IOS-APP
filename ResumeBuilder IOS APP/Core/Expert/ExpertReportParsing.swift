import Foundation

enum ExpertReportParsing {
    /// Parses all structured expert output fields from the `output` JSON.
    static func parsedOutput(from output: JSONValue) -> ExpertOutputParsed {
        guard case .object(let root) = output else { return .empty }

        let summaryOptions: [ExpertSummaryOption] = {
            guard let optVal = root["summary_options"], case .array(let opts) = optVal else { return [] }
            return opts.enumerated().compactMap { idx, val -> ExpertSummaryOption? in
                guard case .object(let o) = val else { return nil }
                let style = string(o["style"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Option \(idx + 1)"
                let summary = string(o["summary"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !summary.isEmpty else { return nil }
                return ExpertSummaryOption(id: idx, style: style, summary: summary)
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
                let impact = string(o["impact"])?.trimmingCharacters(in: .whitespacesAndNewlines)
                let missingMetrics: [String] = {
                    guard let mm = o["missing_metrics"], case .array(let arr) = mm else { return [] }
                    return arr.compactMap { string($0) }.filter { !$0.isEmpty }
                }()
                return ExpertBulletRewrite(
                    id: idx,
                    originalBullet: original,
                    optimizedBullet: optimized,
                    impact: impact,
                    missingMetrics: missingMetrics
                )
            }
        }()

        let atsReport: ExpertATSReport? = {
            guard let atVal = root["ats_report"], case .object(let ats) = atVal else { return nil }
            let score = double(ats["score"])
            let placements: [String] = {
                guard let kp = ats["keyword_placements"], case .array(let arr) = kp else { return [] }
                return arr.compactMap { string($0) }.filter { !$0.isEmpty }
            }()
            let recommended: [String] = {
                guard let rk = ats["recommended_keywords_to_add"], case .array(let arr) = rk else { return [] }
                return arr.compactMap { string($0) }.filter { !$0.isEmpty }
            }()
            let missing: [String] = {
                guard let mk = ats["missing_keywords"], case .array(let arr) = mk else { return [] }
                return arr.compactMap { string($0) }.filter { !$0.isEmpty }
            }()
            guard score != nil || !placements.isEmpty || !recommended.isEmpty || !missing.isEmpty else { return nil }
            return ExpertATSReport(
                score: score,
                keywordPlacements: placements,
                recommendedKeywordsToAdd: recommended,
                missingKeywords: missing
            )
        }()

        let coverLetterVariants: [ExpertCoverLetterVariant] = {
            guard let clVal = root["cover_letter_variants"], case .array(let variants) = clVal else { return [] }
            return variants.enumerated().compactMap { idx, val -> ExpertCoverLetterVariant? in
                guard case .object(let o) = val else { return nil }
                let tone = string(o["tone"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Variant \(idx + 1)"
                let body = string(o["body"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !body.isEmpty else { return nil }
                return ExpertCoverLetterVariant(id: idx, tone: tone, body: body)
            }
        }()

        let screeningAnswers: [ExpertScreeningAnswer] = {
            guard let saVal = root["screening_answers"], case .array(let answers) = saVal else { return [] }
            return answers.enumerated().compactMap { idx, val -> ExpertScreeningAnswer? in
                guard case .object(let o) = val else { return nil }
                let question = string(o["question"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let answer = string(o["answer"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !answer.isEmpty else { return nil }
                return ExpertScreeningAnswer(id: idx, question: question, answer: answer)
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
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : self
    }
}
