import Foundation

/// Decides whether a diagnosis produced while signed out still describes the
/// inputs currently on screen.
///
/// A guest runs the free ATS check, then signs in to optimize. Signing in is not
/// a reason to throw that work away, so the diagnosis survives authentication as
/// long as the résumé and job it was computed from are unchanged. When they do
/// change, only the diagnosis is discarded — the résumé selection and job input
/// belong to the user, not to the result.
struct GuestDiagnosisContinuity: Sendable {

    /// Identity of the inputs a diagnosis depends on.
    ///
    /// Deliberately holds no résumé or job *content*: a sandbox file path and the
    /// already-normalized job input are enough to tell "same inputs" from
    /// "different inputs", which is all this type is allowed to know.
    struct InputFingerprint: Equatable, Sendable {
        let resumePath: String
        let normalizedDescription: String
        let normalizedURL: String

        /// Returns `nil` when the inputs could not have produced a diagnosis —
        /// no résumé, or job input that `JobInputPolicy` would have blocked.
        static func make(resumeURL: URL?, description: String, urlString: String) -> InputFingerprint? {
            guard let resumeURL else { return nil }
            let jobInput = JobInputPolicy.evaluate(description: description, urlString: urlString)
            guard jobInput.isReady else { return nil }
            return InputFingerprint(
                resumePath: resumeURL.path,
                normalizedDescription: jobInput.normalizedDescription ?? "",
                normalizedURL: jobInput.normalizedURL ?? ""
            )
        }
    }

    enum Decision: Equatable, Sendable {
        /// No guest diagnosis was captured, so there is nothing to preserve.
        case noDiagnosis
        /// Inputs are unchanged — the diagnosis still stands and must not be re-run.
        case carryForward
        /// Inputs changed — drop the diagnosis, keep everything the user entered.
        case invalidateDiagnosis
    }

    /// The only step Home may offer once the user is authenticated.
    enum PostAuthStep: Equatable, Sendable {
        /// No usable carried diagnosis — the user runs the analysis themselves.
        case runAnalysis
        /// A carried diagnosis stands — the user continues from it themselves.
        case continueToOptimize
    }

    static func decide(
        capturedAt captured: InputFingerprint?,
        current: InputFingerprint?
    ) -> Decision {
        guard let captured else { return .noDiagnosis }
        guard let current else { return .invalidateDiagnosis }
        return captured == current ? .carryForward : .invalidateDiagnosis
    }

    /// Both cases are user-initiated by construction: authentication never starts
    /// optimization on the user's behalf.
    static func postAuthStep(for decision: Decision) -> PostAuthStep {
        switch decision {
        case .carryForward:
            return .continueToOptimize
        case .invalidateDiagnosis, .noDiagnosis:
            return .runAnalysis
        }
    }
}
