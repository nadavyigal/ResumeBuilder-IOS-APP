import Foundation

/// The single navigation destination owned by Home during the first-session journey.
enum FirstSessionJourneyRoute: Hashable, Identifiable, Sendable {
    case optimizationReview(reviewId: String)
    case diagnosis(optimizationId: String)

    var id: String {
        switch self {
        case .optimizationReview(let reviewId):
            "review:\(reviewId)"
        case .diagnosis(let optimizationId):
            "diagnosis:\(optimizationId)"
        }
    }
}

/// Enforces success ordering without owning app or view state.
@MainActor
enum FirstSessionJourneyTransition {
    @discardableResult
    static func completeApply(
        optimizationId: String?,
        persist: (String) -> Void,
        showPreview: (String) -> Void
    ) -> Bool {
        guard let optimizationId = optimizationId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !optimizationId.isEmpty else {
            return false
        }

        persist(optimizationId)
        showPreview(optimizationId)
        return true
    }
}
