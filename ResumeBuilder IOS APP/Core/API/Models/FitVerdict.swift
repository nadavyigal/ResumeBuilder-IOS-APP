import Foundation

enum FitBand: String, Codable, CaseIterable, Sendable, Equatable {
    case strong
    case stretch
    case skip

    init(rawValueOrDefault value: String?) {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "strong":
            self = .strong
        case "skip":
            self = .skip
        default:
            self = .stretch
        }
    }

    static func derived(from score: Int) -> FitBand {
        switch score {
        case 75...:
            return .strong
        case 50...74:
            return .stretch
        default:
            return .skip
        }
    }
}

struct FitVerdict: Codable, Equatable, Sendable {
    let band: FitBand
    let score: Int
    let scoreNote: String
    let topGaps: [ResumeGap]
    let missingKeywords: [ResumeKeyword]
    let bandWasDerived: Bool

    init(
        band: FitBand,
        score: Int,
        scoreNote: String,
        topGaps: [ResumeGap],
        missingKeywords: [ResumeKeyword],
        bandWasDerived: Bool = false
    ) {
        self.band = band
        self.score = Self.clampScore(score)
        self.scoreNote = scoreNote
        self.topGaps = topGaps
        self.missingKeywords = missingKeywords
        self.bandWasDerived = bandWasDerived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        let verdictString = try c.decodeString(for: ["verdict", "band", "fitBand", "fit_band"])
        let intScore = try c.decodePercent(for: ["score", "matchScore", "match_score", "overall"])
        let nestedScore = try c.decodeNestedScore(for: ["score"])
        let scoreNoteCamel = try c.decodeIfPresent(String.self, forKey: DynamicCodingKey("scoreNote"))
        let scoreNoteSnake = try c.decodeIfPresent(String.self, forKey: DynamicCodingKey("score_note"))
        // Per 2026-06-23 lesson: wrap nested-object probes in try? so a string-array payload
        // (as returned by current prod) does not abort the whole decode.
        let topGapsCamel = c.decodeGapsOrStrings(forKey: "topGaps")
        let topGapsSnake = c.decodeGapsOrStrings(forKey: "top_gaps")
        let missingKeywordsCamel = c.decodeKeywordsOrStrings(forKey: "missingKeywords")
        let missingKeywordsSnake = c.decodeKeywordsOrStrings(forKey: "missing_keywords")

        let score = intScore ?? nestedScore ?? 0
        let band = verdictString.map(FitBand.init(rawValueOrDefault:)) ?? FitBand.derived(from: score)

        self.init(
            band: band,
            score: score,
            scoreNote: scoreNoteCamel ?? scoreNoteSnake ?? Self.defaultScoreNote,
            topGaps: topGapsCamel.isEmpty ? topGapsSnake : topGapsCamel,
            missingKeywords: missingKeywordsCamel.isEmpty ? missingKeywordsSnake : missingKeywordsCamel,
            bandWasDerived: verdictString == nil
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(band, forKey: .verdict)
        try c.encode(score, forKey: .score)
        try c.encode(scoreNote, forKey: .scoreNote)
        try c.encode(topGaps, forKey: .topGaps)
        try c.encode(missingKeywords, forKey: .missingKeywords)
    }

    func replacingScore(_ score: Int, derivingBandWhenNeeded shouldDeriveBand: Bool) -> FitVerdict {
        FitVerdict(
            band: shouldDeriveBand || bandWasDerived ? FitBand.derived(from: Self.clampScore(score)) : band,
            score: score,
            scoreNote: scoreNote,
            topGaps: topGaps,
            missingKeywords: missingKeywords,
            bandWasDerived: shouldDeriveBand || bandWasDerived
        )
    }

    static func from(publicATSResult result: ATSScoreResult) throws -> FitVerdict {
        guard let fit = result.fit else {
            throw FitCheckServiceError.missingFitBlock
        }
        guard let overall = result.score?.overall else {
            return fit
        }
        return fit.replacingScore(overall, derivingBandWhenNeeded: fit.bandWasDerived)
    }

    static let defaultScoreNote = "Estimated fit vs this job, not a hiring guarantee."

    private enum CodingKeys: String, CodingKey {
        case verdict
        case score
        case scoreNote
        case topGaps
        case missingKeywords
    }

    private static func clampScore(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

private extension KeyedDecodingContainer where K == DynamicCodingKey {
    /// Decodes either a `[ResumeGap]` object-array or a plain `[String]` (mapped to gaps).
    /// Returns `[]` on any decode failure so callers never need to throw.
    func decodeGapsOrStrings(forKey key: String) -> [ResumeGap] {
        let codingKey = DynamicCodingKey(key)
        // try? on decodeIfPresent yields Optional<Optional<T>>; flatten with ?? nil
        if let gaps = (try? decodeIfPresent([ResumeGap].self, forKey: codingKey)) ?? nil {
            return gaps
        }
        if let strings = (try? decodeIfPresent([String].self, forKey: codingKey)) ?? nil {
            return strings.compactMap { s in
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return ResumeGap(title: trimmed, explanation: trimmed, severity: .medium)
            }
        }
        return []
    }

    /// Decodes either a `[ResumeKeyword]` object-array or a plain `[String]` (mapped to keywords).
    /// Returns `[]` on any decode failure so callers never need to throw.
    func decodeKeywordsOrStrings(forKey key: String) -> [ResumeKeyword] {
        let codingKey = DynamicCodingKey(key)
        if let keywords = (try? decodeIfPresent([ResumeKeyword].self, forKey: codingKey)) ?? nil {
            return keywords
        }
        if let strings = (try? decodeIfPresent([String].self, forKey: codingKey)) ?? nil {
            return strings.compactMap { s in
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return ResumeKeyword(keyword: trimmed, importance: .medium)
            }
        }
        return []
    }

    func decodeString(for keys: [String]) throws -> String? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try decodeIfPresent(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return nil
    }

    func decodePercent(for keys: [String]) throws -> Int? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try decodeIfPresent(Int.self, forKey: codingKey) {
                return normalizePercent(Double(value))
            }
            if let value = try decodeIfPresent(Double.self, forKey: codingKey) {
                return normalizePercent(value)
            }
            if let value = try decodeIfPresent(String.self, forKey: codingKey),
               let number = Double(value) {
                return normalizePercent(number)
            }
        }
        return nil
    }

    func decodeNestedScore(for keys: [String]) throws -> Int? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            guard let nested = try? decodeIfPresent(FitScorePayload.self, forKey: codingKey) else { continue }
            return nested.overall
        }
        return nil
    }

    private func normalizePercent(_ value: Double) -> Int {
        let percent = value <= 1 ? value * 100 : value
        return min(100, max(0, Int(percent.rounded())))
    }
}

private struct FitScorePayload: Decodable, Sendable {
    let overall: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        overall = try c.decodePercent(for: ["overall", "matchScore", "match_score"])
    }
}
