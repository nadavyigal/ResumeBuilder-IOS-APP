import Foundation

/// The score the user was shown before the optimize journey started.
///
/// The free match check runs before sign-in against a different endpoint than
/// the optimize path. On 2026-07-26 a real run scored 56 there and 51 on the
/// optimize path's original side — same resume, same job. The engine defects
/// behind most of that gap are fixed (WP-45 D7), but the two paths still
/// extract resume text slightly differently, so a residual point of
/// disagreement can survive. A one-point drop is still a drop.
///
/// This carries the first number the user saw across the guest-to-signed-in
/// boundary so `FitJourney` can floor every later stage to it.
///
/// Keyed by resume: a baseline from one resume must never floor another's
/// journey. Session-scoped and in-memory on purpose — this is a display
/// guarantee for the run the user is in, not a durable record. Optimizations
/// are still stored with their real measured scores.
@MainActor
final class FitBaselineStore {
    static let shared = FitBaselineStore()

    private var scoresByResumeID: [String: Int] = [:]

    init() {}

    /// Record the verdict score from a free match check.
    func record(score: Int, resumeID: String?) {
        guard let resumeID, !resumeID.isEmpty else { return }
        // Keep the highest the user has been shown for this resume. Running the
        // check twice against different jobs must not lower the floor.
        scoresByResumeID[resumeID] = max(scoresByResumeID[resumeID] ?? 0, score)
    }

    /// The floor for a resume's journey, if a free check produced one.
    func baseline(forResumeID resumeID: String?) -> Int? {
        guard let resumeID, !resumeID.isEmpty else { return nil }
        return scoresByResumeID[resumeID]
    }

    /// Drop everything. Call on sign-out so one account's floor cannot follow
    /// another into a new session.
    func clear() {
        scoresByResumeID.removeAll()
    }
}
