import XCTest
@testable import ResumeBuilder_IOS_APP

/// Founder direction 2026-07-26, from testing 1.4.7 on device:
/// **the score the user sees must never go down.**
///
/// Seeing the number drop after taking the action the product recommended
/// reads as "you made it worse". The journey is fit -> improved -> expert and
/// it only ever moves forward.
@MainActor
final class FitJourneyTests: XCTestCase {

    func testTheJourneyTheFounderDescribed() {
        // 29 at the fit check, 48 after improving, 63 after experts.
        var journey = FitJourney(fit: 29)
        XCTAssertEqual(journey.currentDisplayedScore, 29)

        journey.record(48, at: .improved)
        XCTAssertEqual(journey.currentDisplayedScore, 48)

        journey.record(63, at: .expert)
        XCTAssertEqual(journey.currentDisplayedScore, 63)
        XCTAssertEqual(journey.totalGain, 34)
    }

    func testAnImprovementThatMeasuresLowerDoesNotPullTheNumberDown() {
        // The defect: ImproveViewModel assigned the rescan result
        // unconditionally, so a worse rescan lowered the number in front of a
        // user who had just paid for an improvement.
        var journey = FitJourney(fit: 48)
        journey.record(41, at: .improved)

        XCTAssertEqual(journey.displayedScore(at: .improved), 48, "must hold, never drop")
        XCTAssertEqual(journey.rawScore(at: .improved), 41, "the measurement is still the truth")
        XCTAssertTrue(journey.regressed(at: .improved), "and the regression stays visible to us")
    }

    func testAnExpertPassThatMeasuresLowerAlsoHolds() {
        var journey = FitJourney(fit: 29, improved: 55)
        journey.record(50, at: .expert)
        XCTAssertEqual(journey.displayedScore(at: .expert), 55)
        XCTAssertTrue(journey.regressed(at: .expert))
    }

    func testTotalGainIsNeverNegative() {
        var journey = FitJourney(fit: 60)
        journey.record(40, at: .improved)
        XCTAssertEqual(journey.totalGain, 0)
    }

    func testStagesNotYetReachedHaveNoScore() {
        let journey = FitJourney(fit: 29)
        XCTAssertEqual(journey.displayedScore(at: .fit), 29)
        XCTAssertNil(journey.displayedScore(at: .improved))
        XCTAssertNil(journey.displayedScore(at: .expert))
        XCTAssertEqual(journey.currentStage, .fit)
    }

    func testPotentialGainIsOnlyClaimedWhenMeasured() {
        // A projection we cannot back with a real measurement is a promise.
        var journey = FitJourney(fit: 29)
        XCTAssertNil(journey.potentialGain(to: .improved), "no measurement, no claim")

        journey.record(48, at: .improved)
        // Now at .improved, so there is no further gain to claim from it.
        XCTAssertNil(journey.potentialGain(to: .improved))
    }

    func testScoresAreClampedToARealRange() {
        var journey = FitJourney(fit: -10)
        XCTAssertEqual(journey.displayedScore(at: .fit), 0)
        journey.record(140, at: .improved)
        XCTAssertEqual(journey.displayedScore(at: .improved), 100)
    }

    func testStagesOrderForward() {
        XCTAssertTrue(FitStage.fit < FitStage.improved)
        XCTAssertTrue(FitStage.improved < FitStage.expert)
    }
}

/// The diagnosis screen printed every gap twice — once as the bold title, once
/// as the grey explanation — because the backend returns the same sentence for
/// a blocker's `title` and its `suggestedAction`. Seen on device 2026-07-26.
@MainActor
final class ResumeGapDeduplicationTests: XCTestCase {

    private func gap(title: String, explanation: String) -> ResumeGap {
        ResumeGap(title: title, explanation: explanation, severity: .medium)
    }

    func testIdenticalTextIsNotPrintedTwice() {
        let text = "Add at least one metric to your most recent role (for example: time saved, revenue, users, or efficiency)"
        XCTAssertFalse(gap(title: text, explanation: text).hasDistinctExplanation)
    }

    func testNearDuplicatesAreAlsoCaught() {
        XCTAssertFalse(
            gap(
                title: "Include timeframes showing speed of delivery (e.g., 'in 3 months')",
                explanation: "include timeframes showing speed of delivery (e.g., 'in 3 months').  "
            ).hasDistinctExplanation
        )
    }

    func testATruncatedRepeatIsCaught() {
        // The grey line was often the same sentence cut short by the layout.
        XCTAssertFalse(
            gap(title: "Add at least one metric to your most recent role",
                explanation: "Add at least one metric").hasDistinctExplanation
        )
    }

    func testGenuinelyDifferentGuidanceStillShows() {
        XCTAssertTrue(
            gap(title: "No quantified impact in your most recent role",
                explanation: "Add a number to at least one bullet: time saved, revenue, or users.")
                .hasDistinctExplanation
        )
    }

    func testEmptyExplanationShowsNothing() {
        XCTAssertFalse(gap(title: "Some gap", explanation: "   ").hasDistinctExplanation)
    }
}

/// The journey as the founder described it, through the view model that the
/// screens actually read.
@MainActor
final class OptimizedResumeJourneyTests: XCTestCase {

    private func model(before: Int?, after: Int?, expert: Int? = nil) -> OptimizedResumeViewModel {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-test",
            atsScoreBefore: before,
            atsScoreAfter: after
        )
        vm.atsScoreAfterExpert = expert
        return vm
    }

    func testTheScoreClimbsThroughTheStages() {
        XCTAssertEqual(model(before: 29, after: nil).currentATSScore, 29)
        XCTAssertEqual(model(before: 29, after: 48).currentATSScore, 48)
        XCTAssertEqual(model(before: 29, after: 48, expert: 63).currentATSScore, 63)
    }

    func testTheStageIsReportedSoTheScreenCanLabelIt() {
        XCTAssertEqual(model(before: 29, after: nil).currentFitStage, .fit)
        XCTAssertEqual(model(before: 29, after: 48).currentFitStage, .improved)
        XCTAssertEqual(model(before: 29, after: 48, expert: 63).currentFitStage, .expert)
    }

    func testAnExpertPassThatMeasuresLowerCannotPullTheNumberDown() {
        let vm = model(before: 29, after: 48, expert: 40)
        XCTAssertEqual(vm.currentATSScore, 48, "holds at what the user already saw")
        XCTAssertEqual(vm.fitJourney.rawScore(at: .expert), 40, "measurement still recorded")
        XCTAssertTrue(vm.fitJourney.regressed(at: .expert))
    }

    func testTheStartingPointIsKeptForTheJourneyStrip() {
        let vm = model(before: 29, after: 48)
        XCTAssertEqual(vm.startingFitScore, 29)
        XCTAssertEqual(vm.fitGainSoFar, 19)
    }

    func testGainIsNeverNegativeEvenWhenTheRewriteMeasuresWorse() {
        let vm = model(before: 55, after: 41)
        XCTAssertEqual(vm.currentATSScore, 55)
        XCTAssertEqual(vm.fitGainSoFar, 0)
    }

    func testStatusLabelReadsTheSameMonotonicNumber() {
        // It used to compute its own `after ?? before`, so the badge could
        // disagree with the ring on the same screen.
        let vm = model(before: 29, after: 48, expert: 40)
        XCTAssertEqual(vm.currentATSScore, 48)
        XCTAssertEqual(vm.atsStatusLabel, "Low")
    }
}

// MARK: - The guest-to-signed-in boundary (WP-45 D7)

@MainActor
final class FitJourneyBaselineTests: XCTestCase {

    /// The exact production failure, reproduced.
    ///
    /// 2026-07-26: the free match check scored 56, then the optimize path's
    /// original side scored 51 for the same resume and the same job. The user
    /// watched the number fall by five points for doing nothing but continue.
    func testTheProductionRegressionCannotRecur() {
        let journey = FitJourney(fit: 51, baseline: 56)

        XCTAssertEqual(journey.displayedScore(at: .fit), 56)
        XCTAssertEqual(journey.currentDisplayedScore, 56)
    }

    /// The residual case the engine fixes cannot fully close: the two endpoints
    /// extract resume text slightly differently, so a point of disagreement can
    /// survive. One point is still a drop.
    func testASinglePointDropIsAlsoHeld() {
        let journey = FitJourney(fit: 57, baseline: 58)

        XCTAssertEqual(journey.currentDisplayedScore, 58)
    }

    func testTheBaselineFloorsEveryLaterStageToo() {
        var journey = FitJourney(fit: 51, baseline: 56)

        // An improvement that lands below where the user already was must not
        // present as progress downward.
        journey.record(54, at: .improved)
        XCTAssertEqual(journey.displayedScore(at: .improved), 56)

        journey.record(71, at: .expert)
        XCTAssertEqual(journey.displayedScore(at: .expert), 71)
    }

    func testGainIsMeasuredFromWhatTheUserFirstSaw() {
        var journey = FitJourney(fit: 51, baseline: 56)
        journey.record(71, at: .improved)

        // Not 71 - 51. The user started at 56 as far as they are concerned.
        XCTAssertEqual(journey.totalGain, 15)
    }

    func testRawMeasurementsSurviveForDiagnostics() {
        let journey = FitJourney(fit: 51, baseline: 56)

        // Suppressing a bad presentation must not hide a bad result from us.
        XCTAssertEqual(journey.rawScore(at: .fit), 51)
        XCTAssertTrue(journey.regressed(at: .fit))
    }

    func testNoBaselineLeavesBehaviourUnchanged() {
        let journey = FitJourney(fit: 51)

        XCTAssertEqual(journey.currentDisplayedScore, 51)
        XCTAssertFalse(journey.regressed(at: .fit))
    }

    func testABaselineAloneShowsNothing() {
        // A free check with no journey yet is not a stage the user has reached.
        let journey = FitJourney(baseline: 56)

        XCTAssertNil(journey.currentDisplayedScore)
        XCTAssertNil(journey.displayedScore(at: .fit))
    }
}
