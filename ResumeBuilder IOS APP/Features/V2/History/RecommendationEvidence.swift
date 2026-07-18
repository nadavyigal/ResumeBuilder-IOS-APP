import Foundation

/// Story 9 — evidence for a recommendation group, per the approved contract
/// (`docs/specs/drafts/recommendation-evidence-backend-contract.md`, alternative B).
///
/// v1 extracts evidence on-device from the résumé and job text the review
/// endpoint already delivers. Every quote is a verbatim substring of its
/// source by construction — the client can never fabricate evidence. When a
/// future response carries backend evidence (v2), it is preferred after the
/// same verbatim re-validation, with local extraction as the fallback.
nonisolated struct RecommendationEvidence: Equatable, Sendable {
    let jobQuotes: [String]
    let resumeQuotes: [String]

    static let maxQuotesPerSide = 3
    static let maxQuoteLength = 280

    static let empty = RecommendationEvidence(jobQuotes: [], resumeQuotes: [])

    var isEmpty: Bool { jobQuotes.isEmpty && resumeQuotes.isEmpty }

    /// Backend evidence (v2) wins when any of its quotes survive verbatim
    /// re-validation against the delivered source texts; otherwise local
    /// extraction (v1) runs. An unknown version is treated as absent.
    static func resolve(
        backend: ReviewEvidenceDTO?,
        afterExcerpt: String,
        jobText: String?,
        resumeText: String?
    ) -> RecommendationEvidence {
        if let backend, backend.version == 1 {
            let job = validated(backend.job, against: jobText)
            let resume = validated(backend.resume, against: resumeText)
            if !job.isEmpty || !resume.isEmpty {
                return RecommendationEvidence(jobQuotes: job, resumeQuotes: resume)
            }
        }
        return extract(afterExcerpt: afterExcerpt, jobText: jobText, resumeText: resumeText)
    }

    /// Deterministic v1 extraction: phrases of the recommended text that occur
    /// verbatim (case-insensitively) in a source produce a bounded quote of the
    /// surrounding sentence or line from that source.
    static func extract(
        afterExcerpt: String,
        jobText: String?,
        resumeText: String?
    ) -> RecommendationEvidence {
        let candidates = candidatePhrases(from: afterExcerpt)
        return RecommendationEvidence(
            jobQuotes: quotes(matching: candidates, in: jobText),
            resumeQuotes: quotes(matching: candidates, in: resumeText)
        )
    }

    // MARK: - Backend validation

    private static func validated(_ quotes: [ReviewEvidenceQuoteDTO]?, against source: String?) -> [String] {
        guard let quotes, let source, !source.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for item in quotes {
            let quote = item.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty,
                  quote.count <= maxQuoteLength,
                  source.contains(quote),
                  seen.insert(quote).inserted else { continue }
            result.append(quote)
            if result.count == maxQuotesPerSide { break }
        }
        return result
    }

    // MARK: - Local extraction

    /// A candidate is a verbatim slice of the recommended text that starts and
    /// ends on a meaningful word. Longer candidates are tried first so the most
    /// specific phrase claims its quote before generic fragments can.
    private static func candidatePhrases(from excerpt: String) -> [String] {
        let tokens = wordTokens(in: excerpt)
        guard !tokens.isEmpty else { return [] }

        struct Candidate { let text: String; let significantCount: Int }
        var candidates: [Candidate] = []
        var seen = Set<String>()

        let maxSpan = 6
        for start in tokens.indices where tokens[start].isSignificant {
            var significant = 0
            for end in start..<min(start + maxSpan, tokens.count) {
                if tokens[end].isSignificant { significant += 1 }
                guard tokens[end].isSignificant, significant >= 2 || (end == start && tokens[start].text.count >= 5) else { continue }
                let text = String(excerpt[tokens[start].range.lowerBound..<tokens[end].range.upperBound])
                if seen.insert(text.lowercased()).inserted {
                    candidates.append(Candidate(text: text, significantCount: significant))
                }
            }
        }

        return candidates
            .sorted {
                if $0.significantCount != $1.significantCount { return $0.significantCount > $1.significantCount }
                return $0.text.count > $1.text.count
            }
            .map(\.text)
    }

    private static func quotes(matching candidates: [String], in source: String?) -> [String] {
        guard let source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var result: [String] = []
        var takenRanges: [Range<String.Index>] = []
        var seen = Set<String>()

        for candidate in candidates {
            guard result.count < maxQuotesPerSide else { break }
            guard let match = source.range(of: candidate, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            guard !takenRanges.contains(where: { $0.overlaps(match) }) else { continue }
            let quoteRange = snippetRange(around: match, in: source)
            let quote = source[quoteRange].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty, seen.insert(quote).inserted else { continue }
            takenRanges.append(quoteRange)
            result.append(quote)
        }
        return result
    }

    /// Expands a match to the surrounding sentence or line, clamped to
    /// `maxQuoteLength` characters with the match kept inside. The result is
    /// always a contiguous slice of `source`, which is what keeps every quote
    /// verbatim by construction.
    private static func snippetRange(around match: Range<String.Index>, in source: String) -> Range<String.Index> {
        let boundaries = CharacterSet(charactersIn: ".!?\n")

        var start = match.lowerBound
        while start > source.startIndex {
            let previous = source.index(before: start)
            if let scalar = source[previous].unicodeScalars.first, boundaries.contains(scalar) { break }
            start = previous
        }

        var end = match.upperBound
        while end < source.endIndex {
            if let scalar = source[end].unicodeScalars.first, boundaries.contains(scalar) {
                end = source.index(after: end)
                break
            }
            end = source.index(after: end)
        }

        // Clamp to the length budget while keeping the matched phrase inside.
        if source.distance(from: start, to: end) > maxQuoteLength {
            let matchLength = source.distance(from: match.lowerBound, to: match.upperBound)
            let budget = max(0, maxQuoteLength - matchLength)
            let before = source.distance(from: start, to: match.lowerBound)
            let leading = min(before, budget / 2)
            start = source.index(match.lowerBound, offsetBy: -leading)
            let remaining = maxQuoteLength - matchLength - leading
            let after = source.distance(from: match.upperBound, to: end)
            end = source.index(match.upperBound, offsetBy: min(after, max(0, remaining)))
        }

        return start..<end
    }

    private struct WordToken {
        let text: String
        let range: Range<String.Index>
        let isSignificant: Bool
    }

    private static func wordTokens(in text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var index = text.startIndex
        while index < text.endIndex {
            if text[index].isLetter || text[index].isNumber {
                let start = index
                while index < text.endIndex, text[index].isLetter || text[index].isNumber {
                    index = text.index(after: index)
                }
                let word = String(text[start..<index])
                let lowered = word.lowercased()
                let significant = word.count >= 3 && !stopwords.contains(lowered)
                tokens.append(WordToken(text: lowered, range: start..<index, isSignificant: significant))
            } else {
                index = text.index(after: index)
            }
        }
        return tokens
    }

    /// Function words only — anything that could be meaningful résumé or job
    /// vocabulary stays significant.
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "are", "was", "were",
        "will", "have", "has", "had", "from", "into", "onto", "your", "you",
        "our", "their", "they", "them", "there", "than", "then", "but", "not",
        "all", "any", "can", "may", "more", "most", "other", "some", "such",
        "out", "over", "per", "she", "him", "her", "his", "its", "also", "who",
        "what", "when", "where", "which", "while", "would", "could", "should",
        "been", "being", "both", "each", "few", "how", "off", "own", "same",
        "too", "very", "via", "well", "yet", "yours",
    ]
}
