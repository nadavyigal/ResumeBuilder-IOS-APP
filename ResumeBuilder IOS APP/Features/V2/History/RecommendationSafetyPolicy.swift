import Foundation

/// Conservative client fallback for recommendation safety while backend evidence
/// metadata is unavailable. It never sends or stores the inspected content.
nonisolated struct RecommendationSafetyPolicy: Sendable {
    enum Reason: String, Hashable, Sendable {
        case unresolvedPlaceholder = "unresolved_placeholder"
        case titleOrSeniority = "title_or_seniority"
        case company
        case date
        case degree
        case location
        case contact
        case numericalAchievement = "numerical_achievement"

        var userMessage: String {
            switch self {
            case .unresolvedPlaceholder:
                return NSLocalizedString("This suggestion contains unfinished template text, so it has been hidden and cannot be applied.", comment: "Blocked recommendation placeholder")
            case .titleOrSeniority:
                return NSLocalizedString("This may change a job title or seniority. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .company:
                return NSLocalizedString("This may change a company or employer name. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .date:
                return NSLocalizedString("This may add, remove, or change a date. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .degree:
                return NSLocalizedString("This may change an education credential. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .location:
                return NSLocalizedString("This may change a location. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .contact:
                return NSLocalizedString("This may change contact information. Confirm it is factually accurate before including it.", comment: "Recommendation factual warning")
            case .numericalAchievement:
                return NSLocalizedString("This may add or change a number or metric. Confirm it is supported by your experience before including it.", comment: "Recommendation factual warning")
            }
        }
    }

    struct Assessment: Equatable, Sendable {
        let reasons: Set<Reason>

        var isSuppressed: Bool { reasons.contains(.unresolvedPlaceholder) }
        var canSelect: Bool { !isSuppressed }
        var requiresExplicitConfirmation: Bool { !reasons.subtracting([.unresolvedPlaceholder]).isEmpty }
        var primaryReason: Reason? {
            let priority: [Reason] = [
                .unresolvedPlaceholder, .titleOrSeniority, .company, .date,
                .degree, .location, .contact, .numericalAchievement,
            ]
            return priority.first(where: reasons.contains)
        }
        var analyticsReason: String { primaryReason?.rawValue ?? "none" }
        var analyticsState: String {
            if isSuppressed { return "blocked" }
            if requiresExplicitConfirmation { return "confirmation_required" }
            return "safe"
        }

        func defaultIncluded(reviewHasNonPositiveDelta: Bool) -> Bool {
            canSelect && !requiresExplicitConfirmation && !reviewHasNonPositiveDelta
        }
    }

    struct ScoreAssessment: Equatable, Sendable {
        let isNonPositive: Bool
    }

    static func assess(before: String?, after: String, context: String = "") -> Assessment {
        let original = before ?? ""
        let generatedSurface = context + "\n" + after
        let changed = normalized(original) != normalized(after)
        let lowerContext = context.lowercased()
        var reasons: Set<Reason> = []

        if containsPlaceholder(generatedSurface) {
            reasons.insert(.unresolvedPlaceholder)
        }

        guard changed else { return Assessment(reasons: reasons) }

        let beforeSeniority = matchingTokens(in: original, pattern: seniorityPattern)
        let afterSeniority = matchingTokens(in: after, pattern: seniorityPattern)
        if containsAny(lowerContext, titleKeywords) || !afterSeniority.subtracting(beforeSeniority).isEmpty {
            reasons.insert(.titleOrSeniority)
        }
        if containsAny(lowerContext, companyKeywords) { reasons.insert(.company) }
        if containsAny(lowerContext, degreeKeywords) { reasons.insert(.degree) }
        if containsAny(lowerContext, locationKeywords) { reasons.insert(.location) }

        let beforeDates = matchingTokens(in: original, pattern: datePattern)
        let afterDates = matchingTokens(in: after, pattern: datePattern)
        if containsAny(lowerContext, dateKeywords) || beforeDates != afterDates, !beforeDates.isEmpty || !afterDates.isEmpty {
            reasons.insert(.date)
        }

        let beforeContacts = matchingTokens(in: original, pattern: contactPattern)
        let afterContacts = matchingTokens(in: after, pattern: contactPattern)
        if containsAny(lowerContext, contactKeywords) || beforeContacts != afterContacts,
           !beforeContacts.isEmpty || !afterContacts.isEmpty {
            reasons.insert(.contact)
        }

        let beforeNumbers = matchingTokens(in: original, pattern: numberPattern)
        let afterNumbers = matchingTokens(in: after, pattern: numberPattern)
        if beforeNumbers != afterNumbers {
            reasons.insert(.numericalAchievement)
        }

        return Assessment(reasons: reasons)
    }

    static func assessScore(before: Double?, after: Double?) -> ScoreAssessment {
        guard let before, let after else { return ScoreAssessment(isNonPositive: false) }
        return ScoreAssessment(isNonPositive: after <= before)
    }

    private static let titleKeywords = ["title", "seniority", "job role", "position"]
    private static let companyKeywords = ["company", "employer", "organization"]
    private static let dateKeywords = ["date", "tenure", "timeline", "duration"]
    private static let degreeKeywords = ["degree", "education", "credential", "university", "college"]
    private static let locationKeywords = ["location", "address", "city", "country"]
    private static let contactKeywords = ["contact", "email", "phone", "telephone"]
    private static let seniorityPattern = #"\b(senior|lead|principal|manager|director|head|chief|vp|vice president)\b"#
    private static let datePattern = #"\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec|19\d{2}|20\d{2})\b"#
    private static let contactPattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|\+?\d[\d\s().-]{6,}\d"#
    private static let numberPattern = #"\b\d+(?:[.,]\d+)?%?\b"#

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func containsPlaceholder(_ value: String) -> Bool {
        value.range(of: #"\{[^{}\n]+\}"#, options: .regularExpression) != nil
    }

    private static func containsAny(_ value: String, _ terms: [String]) -> Bool {
        terms.contains(where: value.contains)
    }

    private static func matchingTokens(in value: String, pattern: String) -> Set<String> {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return Set(expression.matches(in: value, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: value) else { return nil }
            return value[tokenRange].lowercased()
        })
    }
}
