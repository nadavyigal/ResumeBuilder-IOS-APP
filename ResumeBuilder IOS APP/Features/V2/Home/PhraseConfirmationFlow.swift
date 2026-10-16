import SwiftUI

/// G2b: the one owner of "load the review, ask about held lines if there are any,
/// then apply". Screens hold one in `@State`, attach `phraseConfirmationSheet` to a
/// view that is always mounted, and call `start` / `finish`.
///
/// The sheet used to hang off the fit-check destination, so a review that came back
/// with held lines but no fit preview (Home's direct-apply branch) set the pending
/// confirmation with no sheet mounted: nothing was asked and nothing applied (PR #189
/// review). Owning the state here, and mounting the sheet at the screen root, makes
/// every path that applies a review ask the same way.
/// Where the flow loads and applies a review. `service(_:)` in the app; a fake in tests,
/// which cannot construct `AppState` in the test host.
struct PhraseConfirmationBackend {
    let load: @MainActor (_ reviewId: String) async throws -> OptimizationReviewEnvelope
    let apply: @MainActor (
        _ reviewId: String,
        _ envelope: OptimizationReviewEnvelope,
        _ confirmed: Set<String>
    ) async throws -> OptimizationAutoApplyService.Result

    static func service(_ appState: AppState) -> PhraseConfirmationBackend {
        PhraseConfirmationBackend(
            load: { reviewId in
                try await OptimizationAutoApplyService().load(reviewId: reviewId, appState: appState)
            },
            apply: { reviewId, envelope, confirmed in
                try await OptimizationAutoApplyService()
                    .apply(reviewId: reviewId, envelope: envelope, confirmed: confirmed, appState: appState)
            }
        )
    }
}

@Observable
@MainActor
final class PhraseConfirmationFlow {
    enum Outcome {
        /// Applied; land on the résumé.
        case applied(OptimizationAutoApplyService.Result)
        /// Held lines are waiting on the sheet; nothing is applied yet.
        case awaitingConfirmation
    }

    /// Set while held lines wait for the user. Drives the sheet.
    var pending: PendingPhraseConfirmation?

    /// Loads the review. With held lines, waits for the user; without, applies every change.
    func start(reviewId: String, backend: PhraseConfirmationBackend) async throws -> Outcome {
        let envelope = try await backend.load(reviewId)
        if !ConfirmPhraseSelection.claims(in: envelope).isEmpty {
            pending = PendingPhraseConfirmation(reviewId: reviewId, envelope: envelope)
            return .awaitingConfirmation
        }
        return .applied(try await backend.apply(reviewId, envelope, []))
    }

    /// Continue on the sheet: every change plus the lines the user confirmed.
    func finish(
        _ confirmation: PendingPhraseConfirmation,
        confirmed: Set<String>,
        backend: PhraseConfirmationBackend
    ) async throws -> OptimizationAutoApplyService.Result {
        pending = nil
        return try await backend.apply(confirmation.reviewId, confirmation.envelope, confirmed)
    }

    /// Cancel on the sheet: nothing is applied.
    func cancel() {
        pending = nil
    }
}

extension View {
    /// The "Add only if true" sheet for `flow`. Attach it to a view that is always in
    /// the hierarchy, not to a navigation destination that may not be showing.
    func phraseConfirmationSheet(
        _ flow: PhraseConfirmationFlow,
        onContinue: @escaping (PendingPhraseConfirmation, Set<String>) -> Void
    ) -> some View {
        sheet(item: Binding(get: { flow.pending }, set: { if $0 == nil { flow.cancel() } })) { pending in
            AddOnlyIfTrueView(
                claims: pending.claims,
                onContinue: { confirmed in onContinue(pending, confirmed) },
                onCancel: { flow.cancel() }
            )
        }
    }
}

/// What Home does after an optimize call: the diagnosis for a finished optimization,
/// the fit check when the run measured one, otherwise apply the review directly.
/// Every review path goes through `PhraseConfirmationFlow`, so held lines are asked
/// about whether or not there is a fit check.
enum HomeJourneyNextStep: Equatable {
    case diagnosis(optimizationId: String)
    case fitCheck(reviewId: String)
    case applyReview(reviewId: String)
    case stay

    static func after(optimizationId: String?, reviewId: String?, fit: OptimizeFitPreview?) -> HomeJourneyNextStep {
        if let optimizationId, !optimizationId.isEmpty { return .diagnosis(optimizationId: optimizationId) }
        guard let reviewId else { return .stay }
        if let fit, fit.currentScore != nil { return .fitCheck(reviewId: reviewId) }
        return .applyReview(reviewId: reviewId)
    }
}
