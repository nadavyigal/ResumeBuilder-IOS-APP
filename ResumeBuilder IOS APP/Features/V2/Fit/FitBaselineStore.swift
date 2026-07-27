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

    private var scoresByKey: [String: Int] = [:]

    init() {}

    /// Record the verdict score from a free match check, keyed by resume.
    func record(score: Int, resumeID: String?) {
        record(score: score, key: resumeID)
    }

    /// Record a baseline against any identity the journey is keyed by.
    func record(score: Int, key: String?) {
        guard let key, !key.isEmpty else { return }
        // Keep the highest the user has been shown under this key. Running the
        // check twice against different jobs must not lower the floor.
        scoresByKey[key] = max(scoresByKey[key] ?? 0, score)
    }

    /// Carry an existing baseline onto a second identity for the same journey.
    ///
    /// The free check knows the resume id; the screens that later show the
    /// score know the optimization id, and nothing joins the two. Without this
    /// the floor was recorded and then never found — present in the code and
    /// inert in the shipping path.
    func carryForward(from oldKey: String?, to newKey: String?) {
        guard let score = baseline(for: oldKey) else { return }
        record(score: score, key: newKey)
    }

    /// The floor for a resume's journey, if a free check produced one.
    func baseline(forResumeID resumeID: String?) -> Int? {
        baseline(for: resumeID)
    }

    /// The floor recorded under any journey identity.
    func baseline(for key: String?) -> Int? {
        guard let key, !key.isEmpty else { return nil }
        return scoresByKey[key]
    }

    /// Drop everything. Call on sign-out so one account's floor cannot follow
    /// another into a new session.
    func clear() {
        scoresByKey.removeAll()
    }
}
