import Foundation

/// One client-side policy for every first-session job input surface.
///
/// The minimum depends on where the text goes. Tailoring (web `upload-resume`) needs only
/// non-empty text, and the web treats 50 words as usable; the public free check (web
/// `/api/public/ats-check`, `PUBLIC_ATS_MIN_JOB_DESCRIPTION_WORDS`) still needs 100 without
/// a link. The 100-word gate on the tailoring path stopped 4 of 5 people who picked a résumé
/// (2026-10-16 read, build 1.5.1 (29)).
struct JobInputPolicy: Sendable {
    static let minimumPastedWordCount = 50
    static let publicCheckMinimumWordCount = 100

    /// Where the job text is sent.
    enum Destination: Sendable {
        /// Tailoring through `upload-resume` / `optimize`.
        case optimize
        /// The public free check, used without a session and by the fit check.
        case publicCheck

        var minimumWordCount: Int {
            switch self {
            case .optimize: return JobInputPolicy.minimumPastedWordCount
            case .publicCheck: return JobInputPolicy.publicCheckMinimumWordCount
            }
        }
    }

    enum BlockingReason: Equatable, Sendable {
        case missing
        case invalidURL
        case descriptionTooShort

        var analyticsValue: String {
            switch self {
            case .missing: return "missing"
            case .invalidURL: return "invalid_url"
            case .descriptionTooShort: return "description_too_short"
            }
        }
    }

    struct Evaluation: Equatable, Sendable {
        let wordCount: Int
        let minimumWordCount: Int
        let normalizedDescription: String?
        let normalizedURL: String?
        let hasDescriptionInput: Bool
        let hasURLInput: Bool
        let blockingReason: BlockingReason?

        var isReady: Bool { normalizedDescription != nil || normalizedURL != nil }
        var isURLValid: Bool { normalizedURL != nil }
        /// For `job_input_validation_shown`: how close the paste was, never the text.
        var wordCountBucket: String { JobInputPolicy.wordCountBucket(wordCount) }

        var validationMessage: String? {
            switch blockingReason {
            case .missing:
                return String(
                    format: NSLocalizedString(
                        "Add a job link or paste at least %lld words from the job description.",
                        comment: "Job input is empty"
                    ),
                    minimumWordCount
                )
            case .invalidURL:
                return String(
                    format: NSLocalizedString(
                        "Enter a job link, or paste at least %lld words from the job description.",
                        comment: "Job URL is invalid"
                    ),
                    minimumWordCount
                )
            case .descriptionTooShort:
                return String(
                    format: NSLocalizedString(
                        "Paste at least %lld words from the job description (%lld so far).",
                        comment: "Pasted job description is too short: the minimum, then the words pasted"
                    ),
                    minimumWordCount,
                    wordCount
                )
            case nil:
                return nil
            }
        }

        var inlineGuidance: String {
            if isURLValid {
                return String(
                    format: NSLocalizedString(
                        "Job link ready · %lld pasted words (optional)",
                        comment: "Valid URL makes pasted job text optional"
                    ),
                    wordCount
                )
            }
            if blockingReason == .invalidURL, let message = validationMessage {
                return message
            }
            return String(
                format: NSLocalizedString(
                    "%lld of %lld words required when pasting",
                    comment: "Live pasted job description word count: words pasted, then the minimum"
                ),
                wordCount,
                minimumWordCount
            )
        }
    }

    static func evaluate(description: String, urlString: String, destination: Destination = .optimize) -> Evaluation {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = wordCount(in: trimmedDescription)
        let minimum = destination.minimumWordCount
        let normalizedDescription = count >= minimum ? trimmedDescription : nil
        let normalizedURL = normalizedWebURL(from: trimmedURL)

        let blockingReason: BlockingReason?
        if normalizedDescription != nil || normalizedURL != nil {
            blockingReason = nil
        } else if !trimmedURL.isEmpty {
            blockingReason = .invalidURL
        } else if !trimmedDescription.isEmpty {
            blockingReason = .descriptionTooShort
        } else {
            blockingReason = .missing
        }

        return Evaluation(
            wordCount: count,
            minimumWordCount: minimum,
            normalizedDescription: normalizedDescription,
            normalizedURL: normalizedURL,
            hasDescriptionInput: !trimmedDescription.isEmpty,
            hasURLInput: !trimmedURL.isEmpty,
            blockingReason: blockingReason
        )
    }

    static func friendlyInputError() -> String {
        NSLocalizedString(
            "Check the job link or paste more of the job description, then try again.",
            comment: "Server rejected expected job input validation"
        )
    }

    /// Buckets for analytics: "0", "1-24", "25-49", "50-99", "100+".
    static func wordCountBucket(_ count: Int) -> String {
        switch count {
        case ..<1: return "0"
        case 1..<25: return "1-24"
        case 25..<50: return "25-49"
        case 50..<100: return "50-99"
        default: return "100+"
        }
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// A web link from whatever was typed or shared: the value itself when it is a full
    /// http(s) link, else the first link inside it ("Check out this job: https://…"),
    /// with https:// added to a bare domain ("linkedin.com/jobs/view/123").
    private static func normalizedWebURL(from value: String) -> String? {
        guard !value.isEmpty else { return nil }
        if let url = webURL(value) { return url }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(value.startIndex..., in: value)
        for match in detector.matches(in: value, options: [], range: range) {
            guard let found = Range(match.range, in: value) else { continue }
            let text = String(value[found])
            let lowered = text.lowercased()
            if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
                if let url = webURL(text) { return url }
            } else if !lowered.contains("@"), !lowered.contains("://"), let url = webURL("https://" + text) {
                return url
            }
        }
        return nil
    }

    private static func webURL(_ value: String) -> String? {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else {
            return nil
        }
        return components.url?.absoluteString
    }
}

struct JobInputValidationTrackingPolicy: Sendable {
    private var lastReason: JobInputPolicy.BlockingReason?

    mutating func consume(_ reason: JobInputPolicy.BlockingReason?) -> String? {
        defer { lastReason = reason }
        guard let reason, reason != lastReason else { return nil }
        return reason.analyticsValue
    }
}
