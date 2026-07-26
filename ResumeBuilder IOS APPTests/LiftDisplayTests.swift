import XCTest
@testable import ResumeBuilder_IOS_APP

/// WP-45 S8 — a run that did not improve the resume must not be shown as one.
///
/// The moderated session on 2026-07-24 saw "42 before, 44 after". Over 60 days
/// 24 of 59 optimizations ended at +4 or worse and 6 ended lower than they
/// started, so that pair was the modal bad outcome rather than bad luck.
@MainActor
final class LiftDisplayTests: XCTestCase {

    private func model(before: Int?, after: Int?) -> OptimizedResumeViewModel {
        OptimizedResumeViewModel(
            optimizationId: "opt-test",
            atsScoreBefore: before,
            atsScoreAfter: after
        )
    }

    func testTheCaseThatStartedThisIsWithheld() {
        let vm = model(before: 42, after: 44)
        XCTAssertEqual(vm.atsScoreDelta, 2)
        XCTAssertEqual(vm.hasMeaningfulLift, false)
        XCTAssertFalse(vm.shouldDisplayScorePair)
    }

    func testADropIsWithheld() {
        let vm = model(before: 50, after: 47)
        XCTAssertEqual(vm.atsScoreDelta, -3)
        XCTAssertFalse(vm.shouldDisplayScorePair)
    }

    func testARealImprovementIsShown() {
        let vm = model(before: 33, after: 52)
        XCTAssertEqual(vm.hasMeaningfulLift, true)
        XCTAssertTrue(vm.shouldDisplayScorePair)
    }

    func testExactlyTheFloorCounts() {
        let vm = model(before: 40, after: 40 + OptimizedResumeViewModel.minimumMeaningfulLift)
        XCTAssertTrue(vm.shouldDisplayScorePair)
    }

    func testTheScoresThemselvesAreNeverRewritten() {
        // Withholding is a display decision. Clamping the delta positive or
        // flooring the score would be the dishonest fix for the same complaint.
        let vm = model(before: 60, after: 55)
        XCTAssertEqual(vm.atsScoreBefore, 60)
        XCTAssertEqual(vm.atsScoreAfter, 55)
        XCTAssertEqual(vm.atsScoreDelta, -5)
    }

    func testNoComparisonMeansNoPair() {
        XCTAssertNil(model(before: nil, after: 44).hasMeaningfulLift)
        XCTAssertFalse(model(before: nil, after: 44).shouldDisplayScorePair)
    }

    func testTheFloorMatchesTheBackend() {
        // MIN_MEANINGFUL_LIFT in src/lib/ats/lift.ts. If one moves, both must.
        XCTAssertEqual(OptimizedResumeViewModel.minimumMeaningfulLift, 5)
    }
}
