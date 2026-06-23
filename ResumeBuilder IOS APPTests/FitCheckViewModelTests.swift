import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class FitCheckViewModelTests: XCTestCase {

    // MARK: - Validation

    func testCanCheckReturnsFalseForEmptyJD() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        XCTAssertFalse(vm.canCheck)
    }

    func testCanCheckReturnsFalseForShortJD() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.jobDescription = "Too short"
        XCTAssertFalse(vm.canCheck)
    }

    func testCanCheckReturnsTrueForSufficientJD() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.jobDescription = longJD()
        XCTAssertTrue(vm.canCheck)
    }

    func testJobDescriptionTooShortReturnsTrueForPartialInput() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.jobDescription = "Short description that has fewer than fifty words total."
        XCTAssertTrue(vm.jobDescriptionTooShort)
    }

    func testJobDescriptionTooShortReturnsFalseForEmptyInput() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        XCTAssertFalse(vm.jobDescriptionTooShort)
    }

    // MARK: - Missing resume

    func testCheckFitCallsOnNeedResumeWhenResumeURLIsNil() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.jobDescription = longJD()
        var needResumeCalled = false
        vm.onNeedResume = { needResumeCalled = true }

        await vm.checkFit()

        XCTAssertTrue(needResumeCalled)
        XCTAssertNil(vm.result)
    }

    // MARK: - Successful check

    func testCheckFitSetsResultOnSuccess() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.resumeURL = URL(fileURLWithPath: "/tmp/resume.pdf")
        vm.jobDescription = longJD()

        await vm.checkFit()

        XCTAssertNotNil(vm.result)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testIsInVerdictStateAfterSuccessfulCheck() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.resumeURL = URL(fileURLWithPath: "/tmp/resume.pdf")
        vm.jobDescription = longJD()

        await vm.checkFit()

        XCTAssertTrue(vm.isInVerdictState)
    }

    // MARK: - Error handling

    func testCheckFitSetsErrorMessageOnFailure() async {
        let errorService = MockFitCheckService(
            result: FitCheckResult(
                verdict: FitVerdict(band: .skip, score: 0, scoreNote: "", topGaps: [], missingKeywords: []),
                sessionId: nil,
                checksRemaining: nil
            ),
            error: FitCheckServiceError.missingFitBlock
        )
        let vm = FitCheckViewModel(fitCheckService: errorService)
        vm.resumeURL = URL(fileURLWithPath: "/tmp/resume.pdf")
        vm.jobDescription = longJD()

        await vm.checkFit()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.result)
    }

    // MARK: - Reset

    func testResetToEntryClearsResultAndError() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.resumeURL = URL(fileURLWithPath: "/tmp/resume.pdf")
        vm.jobDescription = longJD()
        await vm.checkFit()

        XCTAssertTrue(vm.isInVerdictState)
        vm.resetToEntry()
        XCTAssertFalse(vm.isInVerdictState)
        XCTAssertNil(vm.result)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - CTA callbacks

    func testOptimizeForThisJobCallsOnOptimize() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.resumeURL = URL(fileURLWithPath: "/tmp/resume.pdf")
        vm.jobDescription = longJD()
        await vm.checkFit()

        var receivedJD: String?
        vm.onOptimize = { jd in receivedJD = jd }

        vm.optimizeForThisJob()

        XCTAssertNotNil(receivedJD)
    }

    func testSkipCallsOnSkip() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        var skipCalled = false
        vm.onSkip = { skipCalled = true }

        vm.skip()

        XCTAssertTrue(skipCalled)
    }

    // MARK: - Helpers

    private func longJD() -> String {
        Array(repeating: "engineer required skills experience building distributed scalable systems", count: 8).joined(separator: " ")
    }
}
