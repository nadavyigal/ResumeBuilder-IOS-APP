import Foundation

/// One client-side fallback policy for every first-session job input surface.
/// The 100-word minimum mirrors the current web validation until the backend
/// exposes validation metadata that can replace this local constant.
struct JobInputPolicy: Sendable {
    static let minimumPastedWordCount = 100

    enum BlockingReason: Equatable, Sendable {
        case missing
        case invalidURL
        case descriptionTooShort
    }

    struct Evaluation: Equatable, Sendable {
        let wordCount: Int
        let normalizedDescription: String?
        let normalizedURL: String?
        let hasDescriptionInput: Bool
        let hasURLInput: Bool
        let blockingReason: BlockingReason?

        var isReady: Bool { normalizedDescription != nil || normalizedURL != nil }
        var isURLValid: Bool { normalizedURL != nil }

        var validationMessage: String? {
            switch blockingReason {
            case .missing:
                return NSLocalizedString(
                    "Add a job link or paste at least 100 words from the job description.",
                    comment: "Job input is empty"
                )
            case .invalidURL:
                return NSLocalizedString(
                    "Enter a complete job link beginning with http:// or https://, or paste at least 100 words.",
                    comment: "Job URL is invalid"
                )
            case .descriptionTooShort:
                return String(
                    format: NSLocalizedString(
                        "Paste at least 100 words from the job description (%lld of 100 words).",
                        comment: "Pasted job description is too short"
                    ),
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
            if blockingReason == .invalidURL {
                return NSLocalizedString(
                    "Enter a complete job link beginning with http:// or https://, or paste at least 100 words.",
                    comment: "Job URL is invalid"
                )
            }
            return String(
                format: NSLocalizedString(
                    "%lld of 100 words required when pasting",
                    comment: "Live pasted job description word count"
                ),
                wordCount
            )
        }
    }

    static func evaluate(description: String, urlString: String) -> Evaluation {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = wordCount(in: trimmedDescription)
        let normalizedDescription = count >= minimumPastedWordCount ? trimmedDescription : nil
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
            normalizedDescription: normalizedDescription,
            normalizedURL: normalizedURL,
            hasDescriptionInput: !trimmedDescription.isEmpty,
            hasURLInput: !trimmedURL.isEmpty,
            blockingReason: blockingReason
        )
    }

    static func friendlyInputError() -> String {
        NSLocalizedString(
            "Check the job link or paste at least 100 words from the job description, then try again.",
            comment: "Server rejected expected job input validation"
        )
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private static func normalizedWebURL(from value: String) -> String? {
        guard !value.isEmpty,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else {
            return nil
        }
        return components.url?.absoluteString
    }
}
