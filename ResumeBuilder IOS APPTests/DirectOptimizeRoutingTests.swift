import XCTest
@testable import ResumeBuilder_IOS_APP

/// WP-45 S6 — the authenticated journey starts optimization directly.
///
/// The Fit screen asked for the same intent twice and delivered a discouraging
/// verdict before the product had done anything for the user. A moderated
/// session on 2026-07-24 watched that happen with a score of 45.
final class DirectOptimizeRoutingTests: XCTestCase {

    func testFitGateIsOff() {
        // The routing in HomeTabView and TailorView both branch on this. With
        // it off, Analyze runs the direct path and no Fit sheet is presented.
        XCTAssertFalse(BackendConfig.isFitCheckEnabled)
    }

    func testAnalyticsReportsTheDirectFlow() {
        // S0 instrumented flow_version precisely so the before/after funnel is
        // separable. With the gate off, every analysis_cta_tapped must carry
        // direct_optimize_v2 or the readout compares two different journeys.
        XCTAssertEqual(
            AnalyticsFlowVersion.current(isFitCheckEnabled: BackendConfig.isFitCheckEnabled),
            .directOptimizeV2
        )
    }

    func testDirectFlowVersionSerialisesToTheDocumentedValue() {
        XCTAssertEqual(AnalyticsFlowVersion.directOptimizeV2.rawValue, "direct_optimize_v2")
    }

    func testFitVerdictBandsAreUnreachableAtObservedScores() {
        // Documents why the gate is off rather than merely reordered. Over 60
        // days the free checker's observed maximum was 51 and the authenticated
        // maximum was 62, against a strong threshold of 75. Showing a verdict
        // built on those bands could only ever discourage.
        XCTAssertEqual(FitBand.derived(from: 51), .skip)
        XCTAssertEqual(FitBand.derived(from: 62), .stretch)
        XCTAssertEqual(FitBand.derived(from: 45), .skip)
        XCTAssertEqual(FitBand.derived(from: 75), .strong)
    }
}
