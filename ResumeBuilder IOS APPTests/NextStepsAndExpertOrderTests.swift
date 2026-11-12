import XCTest
@testable import ResumeBuilder_IOS_APP

/// Tester call, 2026-11-12: she went optimize, export, done, and never found
/// the cover letter, screening answers or design. The Expert tab also opened
/// with "Resume Rewrite", the step she had just finished.
final class NextStepsAndExpertOrderTests: XCTestCase {

    // MARK: Expert tab order

    func testExpertTabListsEveryToolExactlyOnce() {
        let order = ExpertWorkflowType.displayOrder
        XCTAssertEqual(Set(order), Set(ExpertWorkflowType.allCases))
        XCTAssertEqual(order.count, ExpertWorkflowType.allCases.count)
    }

    func testCoverLetterComesFirstAndRewriteLast() {
        XCTAssertEqual(ExpertWorkflowType.displayOrder.first, .coverLetterArchitect)
        XCTAssertEqual(ExpertWorkflowType.displayOrder[1], .screeningAnswerStudio)
        XCTAssertEqual(ExpertWorkflowType.displayOrder.last, .fullResumeRewrite)
    }

    // MARK: Before you send

    func testFreshResultPointsAtImproveMatchFirst() {
        let list = BeforeYouSendChecklist(hasImprovedMatch: false, hasCoverLetter: false, hasDesign: false)
        XCTAssertEqual(list.nextStep, .improveMatch)
        XCTAssertFalse(list.isComplete)
    }

    func testAfterImproveMatchTheCoverLetterIsNext() {
        let list = BeforeYouSendChecklist(hasImprovedMatch: true, hasCoverLetter: false, hasDesign: false)
        XCTAssertEqual(list.nextStep, .coverLetter)
    }

    func testSkippingTheCoverLetterStillLeadsToDesign() {
        // Every step is optional: a design chosen without a cover letter is
        // done, and the open cover letter stays the one pointed at.
        let list = BeforeYouSendChecklist(hasImprovedMatch: true, hasCoverLetter: false, hasDesign: true)
        XCTAssertTrue(list.isDone(.design))
        XCTAssertEqual(list.nextStep, .coverLetter)
    }

    func testAllThreeDoneIsComplete() {
        let list = BeforeYouSendChecklist(hasImprovedMatch: true, hasCoverLetter: true, hasDesign: true)
        XCTAssertTrue(list.isComplete)
        XCTAssertNil(list.nextStep)
    }
}
