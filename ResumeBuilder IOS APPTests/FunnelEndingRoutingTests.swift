import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 1 of the funnel-ending design: applying an optimization lands the user
/// on the finished résumé instead of on a diagnosis checkpoint.
///
/// The measured problem: 104 people completed an optimization and 9 ever saw the
/// Optimized screen, because the only route to it was an optional button on a
/// screen that itself reached 5 people. The most common event after
/// `optimization_completed` was `optimization_started` again — 95 people
/// re-running because they did not believe they were done.
final class FunnelEndingRoutingTests: XCTestCase {

    func testWhatChangedEventIsNamedForTheFunnelQuery() {
        // Named so the "did demoting diagnosis lose anything" question can be
        // answered directly against this event rather than inferred.
        XCTAssertEqual(
            AnalyticsEvent.whatChangedTapped(optimizationId: "opt-1").name,
            "what_changed_tapped"
        )
    }

    func testWhatChangedCarriesTheOptimizationId() throws {
        let props = AnalyticsEvent.whatChangedTapped(optimizationId: "opt-42").properties
        XCTAssertEqual(props["optimization_id"], "opt-42")
    }

    func testDiagnosisViewedSurvivesAsItsOwnEvent() {
        // Diagnosis moved position, it was not deleted. If this name ever
        // disappears, the before/after screen has been removed rather than
        // demoted, which is a different decision than the one taken here.
        XCTAssertEqual(
            AnalyticsEvent.diagnosisViewed(matchScore: 61).name,
            "diagnosis_viewed"
        )
    }

    func testExportCTAAndOptimizedViewedRemainDistinctEvents() {
        // These two fire from one guard in OptimizedResumeView and were
        // identical in the data (92 events, 9 people) — which is how the cliff
        // was found. They must stay separately named so the pair can be
        // compared again after this change lands.
        XCTAssertEqual(
            AnalyticsEvent.optimizedViewed(optimizationId: "o").name,
            "optimized_viewed"
        )
        XCTAssertEqual(
            AnalyticsEvent.exportCTASeen(optimizationId: "o").name,
            "export_cta_seen"
        )
        XCTAssertNotEqual(
            AnalyticsEvent.optimizedViewed(optimizationId: "o").name,
            AnalyticsEvent.exportCTASeen(optimizationId: "o").name
        )
    }
}
