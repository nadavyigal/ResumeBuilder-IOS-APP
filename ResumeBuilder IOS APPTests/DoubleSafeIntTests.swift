import XCTest
@testable import ResumeBuilder_IOS_APP

/// The primitive that replaced 26 hand-written `Int(x.rounded())` call sites.
///
/// `Int(_:)` on a `Double` TRAPS — it kills the process, it does not throw — on
/// a value outside `Int`'s range or on NaN. Every score and percentage in this
/// app starts life as a JSON number from the backend, so that initializer was a
/// crash waiting on a malformed response.
@MainActor
final class DoubleSafeIntTests: XCTestCase {

    // MARK: - safeRoundedInt

    func testSafeRoundedIntRoundsTheOrdinaryCases() {
        XCTAssertEqual((2.5).safeRoundedInt, 3)
        XCTAssertEqual((3.75).safeRoundedInt, 4)
        XCTAssertEqual((0.6).safeRoundedInt, 1)
        XCTAssertEqual((0.4).safeRoundedInt, 0)
        XCTAssertEqual((7.0).safeRoundedInt, 7)
        XCTAssertEqual((-2.5).safeRoundedInt, -3)
    }

    /// The whole point: these inputs used to kill the process.
    func testSafeRoundedIntYieldsNoValueForTheUnrepresentable() {
        XCTAssertNil((1e308).safeRoundedInt, "beyond Int.max")
        XCTAssertNil((-1e308).safeRoundedInt, "beyond Int.min")
        XCTAssertNil(Double.nan.safeRoundedInt, "NaN traps Int(_:)")
        XCTAssertNil(Double.infinity.safeRoundedInt)
        XCTAssertNil((-Double.infinity).safeRoundedInt)
    }

    /// `Int.max` is not exactly representable as a `Double`, so the nearest
    /// `Double` sits above it and must be rejected rather than wrapped.
    func testSafeRoundedIntRejectsTheBoundaryRatherThanWrapping() {
        XCTAssertNil(Double(Int.max).safeRoundedInt)
        XCTAssertEqual((9_007_199_254_740_992.0).safeRoundedInt, 9_007_199_254_740_992,
                       "2^53 is exact in Double and fits Int, so it survives")
    }

    // MARK: - displayPercent

    func testDisplayPercentScalesFractions() {
        XCTAssertEqual((0.82).displayPercent, 82)
        XCTAssertEqual((0.0).displayPercent, 0)
        XCTAssertEqual((1.0).displayPercent, 100, "the documented 0...1 ambiguity, preserved")
    }

    func testDisplayPercentLeavesWholePercentagesAlone() {
        XCTAssertEqual((74.0).displayPercent, 74)
        XCTAssertEqual((29.0).displayPercent, 29)
        XCTAssertEqual((42.4).displayPercent, 42)
    }

    /// The clamp runs in `Double` space, before the conversion. Clamping after
    /// it — which several call sites did — never protects these inputs.
    func testDisplayPercentClampsRatherThanCrashing() {
        XCTAssertEqual((1e308).displayPercent, 100)
        XCTAssertEqual((-1e308).displayPercent, 0)
        XCTAssertEqual(Double.infinity.displayPercent, 100)
        XCTAssertEqual((-Double.infinity).displayPercent, 0)
        XCTAssertEqual((150.0).displayPercent, 100)
        XCTAssertEqual((-5.0).displayPercent, 0)
    }

    /// `max(0, .nan)` is 0 because Swift's `max` returns its first argument when
    /// the comparison is false. That is what absorbs NaN here.
    func testDisplayPercentAbsorbsNaN() {
        XCTAssertEqual(Double.nan.displayPercent, 0)
    }

    // MARK: - The call sites that read straight off the wire

    /// `PendingScoreDecrease` holds two `Double`s taken from the expert apply
    /// response, and renders both as percentages in a blocking dialog.
    func testAPendingScoreDecreaseSurvivesAnAbsurdMeasurement() {
        let pending = PendingScoreDecrease(runId: "r1", kept: 1e308, measured: -1e308)
        XCTAssertEqual(pending.keptPercent, 0, "unrepresentable degrades to 0, never a trap")
        XCTAssertEqual(pending.measuredPercent, 0)
    }

    /// These two are deliberately NOT scaled by `displayPercent`: they are
    /// siblings of `before`/`after` on `ExpertAtsImpactResult`, which have
    /// always rendered unscaled. Scaling would report a genuine 1.0 as 100% in
    /// the dialog the user makes a decision on.
    func testAPendingScoreDecreaseDoesNotRescaleASmallScore() {
        let pending = PendingScoreDecrease(runId: "r1", kept: 1, measured: 0.4)
        XCTAssertEqual(pending.keptPercent, 1, "1.0 stays 1%, it does not become 100%")
        XCTAssertEqual(pending.measuredPercent, 0)
    }

    func testAPendingScoreDecreaseRendersOrdinaryScores() {
        let pending = PendingScoreDecrease(runId: "r1", kept: 74, measured: 61)
        XCTAssertEqual(pending.keptPercent, 74)
        XCTAssertEqual(pending.measuredPercent, 61)
    }

    /// A nil `kept` is the "no prior score" case and must read as 0, not crash.
    func testAPendingScoreDecreaseWithNoKeptScoreReadsAsZero() {
        let pending = PendingScoreDecrease(runId: nil, kept: nil, measured: 61)
        XCTAssertEqual(pending.keptPercent, 0)
    }

    /// `integerAverage` returns nil for an empty set and an average otherwise.
    func testIntegerAverageIsUnchangedByTheSafeConversion() {
        XCTAssertNil(ATSSubScores.integerAverage(of: [nil, nil]))
        XCTAssertEqual(ATSSubScores.integerAverage(of: [10, 20, 30]), 20)
        XCTAssertEqual(ATSSubScores.integerAverage(of: [10, nil, 15]), 13, "12.5 rounds to 13")
    }
}
