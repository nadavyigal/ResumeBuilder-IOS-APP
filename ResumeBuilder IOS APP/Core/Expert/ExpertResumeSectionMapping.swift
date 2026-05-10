import Foundation

/// Maps `rewritten_resume`-shaped JSON into the section list used across Optimize / Improve.
enum ExpertResumeSectionMapping {
    /// Builds section cards from expert `rewritten_resume` object (OptimizedResume JSON).
    static func sections(fromRewrittenResume json: JSONValue) -> [OptimizedResumeSection]? {
        guard case .object(let o) = json else { return nil }
        var sections: [OptimizedResumeSection] = []

        if let text = flattenSummary(o["summary"]) {
            sections.append(
                OptimizedResumeSection(id: "summary", type: .summary, body: text, status: "improved")
            )
        }
        if let text = flattenSkills(o["skills"]) {
            sections.append(
                OptimizedResumeSection(id: "skills", type: .skills, body: text, status: "improved")
            )
        }
        if let text = flattenExperience(o["experience"]) {
            sections.append(
                OptimizedResumeSection(id: "experience", type: .experience, body: text, status: "improved")
            )
        }
        if let text = flattenEducation(o["education"]) {
            sections.append(
                OptimizedResumeSection(id: "education", type: .education, body: text, status: "improved")
            )
        }
        if let text = flattenString(o["certifications"]) {
            sections.append(
                OptimizedResumeSection(id: "additional", type: .additional, body: text, status: "improved")
            )
        }

        return sections.isEmpty ? nil : sections
    }

    static func patchSummaryLab(into sections: inout [OptimizedResumeSection], output: JSONValue) {
        guard let chosen = selectSummaryText(from: output), !chosen.isEmpty else { return }
        if let idx = sections.firstIndex(where: { $0.type == .summary }) {
            sections[idx].body = chosen
            sections[idx].status = "improved"
        } else {
            sections.append(
                OptimizedResumeSection(id: "summary", type: .summary, body: chosen, status: "improved")
            )
        }
    }

    static func patchQuantifierBullets(into sections: inout [OptimizedResumeSection], output: JSONValue) {
        guard case .object(let o) = output,
              let bulletVal = o["bullet_rewrites"],
              case .array(let rows) = bulletVal else {
            return
        }
        guard let idx = sections.firstIndex(where: { $0.type == .experience }) else { return }
        var body = sections[idx].body
        for row in rows {
            guard case .object(let br) = row else { continue }
            let original = flattenString(br["original_bullet"]) ?? ""
            let optimized = flattenString(br["optimized_bullet"]) ?? ""
            guard !original.isEmpty, !optimized.isEmpty else { continue }
            if body.contains(original) {
                body = body.replacingOccurrences(of: original, with: optimized)
            }
        }
        sections[idx].body = body
        sections[idx].status = "improved"
    }

    static func patchSkillsFromAtsReport(into sections: inout [OptimizedResumeSection], output: JSONValue) {
        guard case .object(let root) = output,
              let rep = root["ats_report"], case .object(let ats) = rep else {
            return
        }
        guard let kwVal = ats["recommended_keywords_to_add"],
              case .array(let keywords) = kwVal else {
            return
        }
        let additions = keywords.compactMap { flattenString($0) }.filter { !$0.isEmpty }
        guard !additions.isEmpty else { return }
        guard let idx = sections.firstIndex(where: { $0.type == .skills }) else {
            let merged = additions.joined(separator: ", ")
            sections.append(
                OptimizedResumeSection(id: "skills", type: .skills, body: merged, status: "improved")
            )
            return
        }
        let haystack = sections[idx].body.lowercased()
        let fresh = additions.filter { !haystack.contains($0.lowercased()) }
        guard !fresh.isEmpty else { return }
        let prefix = sections[idx].body.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = fresh.joined(separator: ", ")
        if prefix.isEmpty {
            sections[idx].body = suffix
        } else {
            sections[idx].body = prefix + ", " + suffix
        }
        sections[idx].status = "improved"
    }

    // MARK: - Summary lab selection

    private static func selectSummaryText(from output: JSONValue) -> String? {
        guard case .object(let o) = output,
              let optVal = o["summary_options"],
              case .array(let options) = optVal else {
            return nil
        }
        guard !options.isEmpty else { return nil }

        let recIdx = intFromFlexible(o["recommended_index"]) ?? 0
        let idx = max(0, min(recIdx, options.count - 1))
        guard case .object(let chosenObj) = options[idx] else { return nil }
        let summaryRaw = flattenString(chosenObj["summary"]) ?? ""
        let trimmed = summaryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func intFromFlexible(_ val: JSONValue?) -> Int? {
        guard let val else { return nil }
        if case .number(let n) = val { return Int(n.rounded()) }
        if case .string(let s) = val { return Int(s) }
        return nil
    }

    // MARK: - Flatten (aligned with Optimize section text conventions)

    private static func flattenString(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        if case .string(let s) = val {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return nil
    }

    private static func flattenSummary(_ val: JSONValue?) -> String? {
        flattenString(val)
    }

    private static func flattenSkills(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .string(let s):
            return flattenString(.string(s))
        case .object(let obj):
            var lines: [String] = []
            if let technical = obj["technical"], case .array(let tech) = technical {
                lines.append(contentsOf: strings(from: tech))
            }
            if let softVal = obj["soft"], case .array(let soft) = softVal {
                lines.append(contentsOf: strings(from: soft))
            }
            let merged = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return merged.isEmpty ? nil : merged
        default:
            return nil
        }
    }

    private static func flattenExperience(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .array(let rows):
            return rows.compactMap { flattenExperienceRow($0) }.joined(separator: "\n\n")
        default:
            return nil
        }
    }

    private static func flattenExperienceRow(_ row: JSONValue) -> String? {
        guard case .object(let r) = row else { return nil }
        let title =
            flattenString(r["title"])
                ?? flattenString(r["jobTitle"])
                ?? flattenString(r["role"])
        let company = flattenString(r["company"]) ?? flattenString(r["organization"])
        let parts = [title, company].compactMap { $0 }
        let head = parts.joined(separator: " • ")
        var bullets: [String] = []
        if let achievements = r["achievements"], case .array(let ach) = achievements {
            bullets = strings(from: ach).map { "• \($0)" }
        }
        if let desc = r["description"], let line = flattenString(desc) {
            bullets.insert(line, at: 0)
        }
        var linesOut: [String] = []
        if !head.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { linesOut.append(head) }
        linesOut.append(contentsOf: bullets)
        let body = linesOut.joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : body
    }

    private static func flattenEducation(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .array(let rows):
            let text = rows.compactMap { row -> String? in
                guard case .object(let o) = row else { return nil }
                let school =
                    flattenString(o["school"])
                        ?? flattenString(o["institution"])
                        ?? flattenString(o["name"])
                let degree = flattenString(o["degree"])
                let years = flattenString(o["years"]) ?? flattenString(o["period"])
                let line = [degree, school, years].compactMap { $0 }.joined(separator: " • ")
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
            .joined(separator: "\n")
            return text.isEmpty ? nil : text
        default:
            return flattenString(val)
        }
    }

    private static func strings(from values: [JSONValue]) -> [String] {
        values.compactMap { flattenString($0) }
    }
}
