import XCTest
@testable import ResumeBuilder_IOS_APP

/// The Optimized screen showed a full US Letter page, which filled the phone,
/// so a tester never found the score or the next steps below it
/// (2026-11-12). The card now shows the top of the page only.
final class InlineResumePreviewLayoutTests: XCTestCase {

    func testCardShowsTheTopHalfOfTheUSLetterPage() {
        let width: CGFloat = 370 // iPhone 17 width minus the screen's side padding
        let fullPageHeight = width * 11 / 8.5

        XCTAssertEqual(InlineResumePreviewLayout.cardHeight(forWidth: width), fullPageHeight * 0.5, accuracy: 0.01)
    }

    func testCardLeavesRoomForTheScorePanelOnTheSmallestSupportedPhone() {
        // iPhone SE: 667pt tall. Navigation bar (~100) + pinned export bar (~150)
        // leave ~417pt; the card must take well under that.
        let height = InlineResumePreviewLayout.cardHeight(forWidth: 343)

        XCTAssertLessThan(height, 300)
    }

    func testCardIsShorterThanAFullPage() {
        XCTAssertGreaterThan(
            InlineResumePreviewLayout.cardAspectRatio,
            InlineResumePreviewLayout.pageAspectRatio
        )
    }

    func testZeroWidthGivesZeroHeight() {
        XCTAssertEqual(InlineResumePreviewLayout.cardHeight(forWidth: 0), 0)
    }
}
