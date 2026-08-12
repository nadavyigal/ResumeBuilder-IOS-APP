import Foundation

/// Applies a review's changes without showing the review screen.
///
/// The flow used to be: fit check → accept → **Optimization Review** → tick the
/// changes you want → apply → résumé. The review screen is now out of the happy
/// path (founder decision, 2026-08-12): accepting at the fit check applies the
/// changes and lands the user on the finished résumé. The before/after detail the
/// review screen carried moves to Resume Diagnosis, reachable from the résumé.
///
/// **Every change is applied**, including ones `RecommendationSafetyPolicy` marks
/// as needing confirmation. That is a deliberate product choice and a change in
/// behaviour: previously those groups were left unticked by default and a user had
/// to opt in. Nothing is applied invisibly — Resume Diagnosis shows what was
/// applied, and flags the ones the policy would have held back.
@MainActor
struct OptimizationAutoApplyService {
    struct Result {
        let optimizationId: String
        let envelope: OptimizationReviewEnvelope
        /// Groups the safety policy would not have pre-selected. Applied anyway,
        /// surfaced in diagnosis so the user can see what landed.
        let flaggedGroupIds: Set<String>
    }

    enum ServiceError: LocalizedError {
        case applyReturnedNoOptimization(String?)

        var errorDescription: String? {
            switch self {
            case .applyReturnedNoOptimization(let message):
                return message ?? NSLocalizedString(
                    "We could not finish tailoring your résumé. Please try again.",
                    comment: "Auto-apply failed without a specific server message"
                )
            }
        }
    }

    private let api: APIClient
    private let applyTimeout: TimeInterval = 120

    init(api: APIClient = RuntimeServices.sharedAPIClient) {
        self.api = api
    }

    /// Loads the review, applies every group, and returns the new optimization.
    ///
    /// Emits the same analytics the review screen did, so the funnel keeps its
    /// shape across this change: `optimization_apply_started` →
    /// `optimization_apply_succeeded` → `optimization_completed(path: .applied)`.
    /// `approved_group_count` therefore now reports every group rather than the
    /// user's selection, which is exactly what is happening.
    func applyAll(reviewId: String, appState: AppState) async throws -> Result {
        let envelope: OptimizationReviewEnvelope = try await appState.callWithFreshToken { token in
            try await api.get(endpoint: .optimizationReview(id: reviewId), token: token)
        }

        let allGroupIds = envelope.review.groupedChanges.map(\.id)
        let flagged = Self.flaggedGroupIds(in: envelope)

        AnalyticsService.shared.track(
            .optimizationApplyStarted(reviewId: reviewId, approvedGroupCount: allGroupIds.count)
        )

        let response: OptimizationReviewApplyResponseDTO = try await appState.callWithFreshToken { token in
            try await api.postJSON(
                endpoint: .optimizationReviewApply(id: reviewId),
                body: ["approvedGroupIds": allGroupIds],
                token: token,
                timeout: applyTimeout
            )
        }

        guard let optimizationId = response.optimizationId?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !optimizationId.isEmpty
        else {
            AnalyticsService.shared.track(
                .optimizationApplyFailed(
                    reviewId: reviewId,
                    reason: "backend_rejected",
                    errorCode: "backend_error"
                )
            )
            throw ServiceError.applyReturnedNoOptimization(response.error)
        }

        AnalyticsService.shared.track(
            .optimizationApplySucceeded(optimizationId: optimizationId, reviewId: reviewId)
        )
        AnalyticsService.shared.track(
            .optimizationCompleted(optimizationId: optimizationId, reviewId: reviewId, path: .applied)
        )

        return Result(
            optimizationId: optimizationId,
            envelope: envelope,
            flaggedGroupIds: flagged
        )
    }

    /// Groups the safety policy would have left unticked.
    ///
    /// Kept as data rather than as a filter: the product decision is to apply
    /// these, and the honest handling is to show the user which ones they were.
    static func flaggedGroupIds(in envelope: OptimizationReviewEnvelope) -> Set<String> {
        let nonPositive = RecommendationSafetyPolicy.assessScore(
            before: envelope.review.atsPreview?.before,
            after: envelope.review.atsPreview?.after
        ).isNonPositive

        return Set(
            envelope.review.groupedChanges.compactMap { group in
                let assessment = RecommendationSafetyPolicy.assess(
                    before: group.beforeExcerpt,
                    after: group.afterExcerpt,
                    context: [group.section, group.title, group.summary].joined(separator: "\n")
                )
                return assessment.defaultIncluded(reviewHasNonPositiveDelta: nonPositive)
                    ? nil
                    : group.id
            }
        )
    }
}
