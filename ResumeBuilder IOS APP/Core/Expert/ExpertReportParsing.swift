import Foundation

enum ExpertReportParsing {
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
