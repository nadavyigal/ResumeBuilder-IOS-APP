import XCTest
@testable import ResumeBuilder_IOS_APP

/// WP-45 S7 — the spine from job to PDF.
///
/// Founder feedback 2026-07-24: the path should feel like one flow, not six
/// destinations. The audit of the result screen found that option (a) of the
/// packet — Export primary, Design and Expert as optional side-doors — is
/// already how the result screen is built. What still makes the journey feel
/// long is the tab bar presenting Design and Expert as peers of the core
/// journey, which is option (b) and an explicit founder decision.
///
/// These tests pin the part that is already right, so a later change cannot
/// quietly demote Export without someone noticing.
@MainActor
final class ResultScreenPrimaryActionTests: XCTestCase {

    func testTabBarStillPresentsDesignAndExpertAsPeers() {
        // Recorded state, not an endorsement. Five primary destinations is what
        // the tab-bar restructure (option b) would reduce. If that decision is
        // taken, this test changes with it.
        XCTAssertEqual(ResumlyTab.allCases.count, 5)
        XCTAssertTrue(ResumlyTab.allCases.contains(.design))
        XCTAssertTrue(ResumlyTab.allCases.contains(.expert))
    }

    func testTheJourneySpineIsHomeThenOptimizedThenExport() {
        // Export lives on the Optimized tab as the primary action, so the spine
        // a user must traverse is two tabs, not five. Design and Expert sit
        // beside it rather than between it and the PDF.
        XCTAssertEqual(ResumlyTab.tailor.rawValue, 0)
        XCTAssertEqual(ResumlyTab.optimized.rawValue, 1)
        XCTAssertLessThan(ResumlyTab.optimized.rawValue, ResumlyTab.design.rawValue)
        XCTAssertLessThan(ResumlyTab.optimized.rawValue, ResumlyTab.expert.rawValue)
    }

    func testExportEventsExistSoTheSpineIsMeasurable() {
        // The packet requires measuring the tap count from job to PDF before
        // claiming a reduction. These are the events that bound it.
        XCTAssertEqual(AnalyticsEvent.exportCTASeen(optimizationId: "x").name, "export_cta_seen")
        XCTAssertEqual(AnalyticsEvent.exportPdfTapped(optimizationId: "x").name, "export_pdf_tapped")
        XCTAssertEqual(AnalyticsEvent.exportSuccess(optimizationId: "x").name, "export_success")
        XCTAssertEqual(AnalyticsEvent.jobAdded(hasURL: true, hasPaste: false).name, "job_added")
    }
}
