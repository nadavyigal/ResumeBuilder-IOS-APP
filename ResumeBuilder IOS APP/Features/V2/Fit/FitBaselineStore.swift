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
/// journey, and a different job on the same resume replaces the floor instead
/// of keeping the higher one. The same job still keeps the higher score.
/// Session-scoped and in-memory on purpose — this is a display
/// guarantee for the run the user is in, not a durable record. Optimizations
/// are still stored with their real measured scores.
@MainActor
final class FitBaselineStore {
    static let shared = FitBaselineStore()

    private struct Baseline {
        var score: Int
        var jobKey: String?
    }

    private var scoresByKey: [String: Baseline] = [:]

    init() {}

    /// A job identity for the floor. A URL and a pasted description of a
    /// different posting are different jobs, so neither one inherits the other's score.
    static func jobKey(url: String?, description: String?) -> String? {
        if let url, !url.isEmpty { return "url:\(url)" }
        if let description, !description.isEmpty { return "text:\(description)" }
        return nil
    }

    /// Record the verdict score from a free match check, keyed by resume.
    func record(score: Int, resumeID: String?, jobKey: String? = nil) {
        record(score: score, key: resumeID, jobKey: jobKey)
    }

    /// Record a baseline against any identity the journey is keyed by.
    ///
    /// The same job keeps the highest score the user has already been shown.
    /// A different job replaces it, so one posting cannot floor another.
    func record(score: Int, key: String?, jobKey: String? = nil) {
        guard let key, !key.isEmpty else { return }
        guard let existing = scoresByKey[key] else {
            scoresByKey[key] = Baseline(score: score, jobKey: jobKey)
            return
        }
        let differentJob = existing.jobKey != nil && jobKey != nil && existing.jobKey != jobKey
        if differentJob {
            scoresByKey[key] = Baseline(score: score, jobKey: jobKey)
        } else {
            scoresByKey[key] = Baseline(score: max(existing.score, score), jobKey: existing.jobKey ?? jobKey)
        }
    }

    /// Carry an existing baseline onto a second identity for the same journey.
    ///
    /// The free check knows the resume id; the screens that later show the
    /// score know the optimization id, and nothing joins the two. Without this
    /// the floor was recorded and then never found — present in the code and
    /// inert in the shipping path. The job identity travels with the score, so
    /// a later posting cannot overwrite an optimization that already has one.
    func carryForward(from oldKey: String?, to newKey: String?) {
        guard let oldKey, let existing = scoresByKey[oldKey] else { return }
        record(score: existing.score, key: newKey, jobKey: existing.jobKey)
    }

    /// The floor for a resume's journey, if a free check produced one.
    func baseline(forResumeID resumeID: String?) -> Int? {
        baseline(for: resumeID)
    }

    /// The floor recorded under any journey identity.
    func baseline(for key: String?) -> Int? {
        guard let key, !key.isEmpty else { return nil }
        return scoresByKey[key]?.score
    }

    /// Drop everything. Call on sign-out so one account's floor cannot follow
    /// another into a new session.
    func clear() {
        scoresByKey.removeAll()
    }
}
