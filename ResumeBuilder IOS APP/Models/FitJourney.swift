import Foundation

/// The user's fit score as a journey with stages, not a single number.
///
/// Founder direction 2026-07-26, after testing 1.4.7 on device: the flow is
/// optimize, then fit check, then improve, then experts — and **the number the
/// user sees must never go down**. Seeing a score drop after taking the action
/// the product recommended is the single most damaging thing this screen can
/// do; it reads as "you made it worse", and it is the reason the previous
/// pre-optimization gate was removed.
///
/// The stages map onto scores that already exist:
///
///   .fit       the original resume against this job  (`ats_score_original`)
///   .improved  after the optimization is applied     (`ats_score_optimized`)
///   .expert    after expert passes                   (rescan result)
///
/// This type owns the display rule so no screen has to remember it.
enum FitStage: Int, Comparable, CaseIterable, Sendable {
    /// Where the resume started against this job.
    case fit = 0
    /// After the tailored rewrite is applied.
    case improved = 1
    /// After expert passes add evidence the rewrite could not.
    case expert = 2

    static func < (lhs: FitStage, rhs: FitStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A score that can only move forward.
///
/// Every stage records its raw measurement, and `displayed` applies the
/// guarantee: the number shown at a stage is never below the number already
/// shown at an earlier one. The raw values are kept so a regression is still
/// visible in diagnostics and analytics — this suppresses a bad *presentation*,
/// it does not hide a bad *result* from us.
struct FitJourney: Equatable, Sendable {
    private(set) var rawScores: [FitStage: Int] = [:]

    init(fit: Int? = nil, improved: Int? = nil, expert: Int? = nil) {
        if let fit { rawScores[.fit] = Self.clamp(fit) }
        if let improved { rawScores[.improved] = Self.clamp(improved) }
        if let expert { rawScores[.expert] = Self.clamp(expert) }
    }

    private static func clamp(_ value: Int) -> Int { min(100, max(0, value)) }

    /// Record a measurement for a stage. Raw values are stored as measured.
    mutating func record(_ score: Int, at stage: FitStage) {
        rawScores[stage] = Self.clamp(score)
    }

    /// The raw measurement, before the never-decrease rule.
    func rawScore(at stage: FitStage) -> Int? { rawScores[stage] }

    /// The score to show for a stage: never below any earlier stage's shown value.
    ///
    /// A rescan that comes back lower than where the user already was does not
    /// pull the number down; it holds. That is a display guarantee, not a
    /// rewrite of the measurement — `rawScore(at:)` still returns the truth and
    /// `regressed(at:)` reports it.
    func displayedScore(at stage: FitStage) -> Int? {
        guard rawScores[stage] != nil else { return nil }
        var best = 0
        var found = false
        for candidate in FitStage.allCases where candidate <= stage {
            if let raw = rawScores[candidate] {
                best = max(best, raw)
                found = true
            }
        }
        return found ? best : nil
    }

    /// Did this stage measure lower than the user has already been shown?
    ///
    /// Not user-facing. It means the pipeline produced a worse result than the
    /// previous step, which is a product defect worth counting rather than a
    /// number to render.
    func regressed(at stage: FitStage) -> Bool {
        guard let raw = rawScores[stage], let shown = displayedScore(at: stage) else { return false }
        return raw < shown
    }

    /// The furthest stage the user has reached.
    var currentStage: FitStage? {
        FitStage.allCases.filter { rawScores[$0] != nil }.max()
    }

    /// The number to show right now.
    var currentDisplayedScore: Int? {
        guard let stage = currentStage else { return nil }
        return displayedScore(at: stage)
    }

    /// Gain from the starting point to where the user is now, never negative.
    var totalGain: Int? {
        guard let start = displayedScore(at: .fit), let now = currentDisplayedScore else { return nil }
        return max(0, now - start)
    }

    /// What the next stage could add, when we can say it honestly.
    ///
    /// Nil when there is no measured next stage — a projection we cannot back
    /// with a real measurement is a promise, and this product has already been
    /// burned by showing numbers it could not stand behind.
    func potentialGain(to stage: FitStage) -> Int? {
        guard let now = currentDisplayedScore, let next = displayedScore(at: stage), next > now else {
            return nil
        }
        return next - now
    }
}
