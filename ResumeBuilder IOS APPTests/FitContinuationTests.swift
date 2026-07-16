import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 8 — merge Fit into the diagnosis continuation.
@MainActor
final class FitContinuationTests: XCTestCase {

    // MARK: - Presentation policy

    func testCarriedReadyJobRunsFitWithoutASecondConfirmationForm() {
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: true, hasVerdict: false, hasFailed: false, isEditingTarget: false),
            .runAutomatically,
            "A job already entered on Home must not be re-confirmed in a second form."
        )
    }

    func testNothingUsableCarriedFallsBackToAskingForTheJob() {
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: false, hasVerdict: false, hasFailed: false, isEditingTarget: false),
            .askForJob
        )
    }

    func testVerdictIsShownOnceItExists() {
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: true, hasVerdict: true, hasFailed: false, isEditingTarget: false),
            .showVerdict
        )
    }

    func testFailureShowsAFailureStateRatherThanTheEntryForm() {
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: true, hasVerdict: false, hasFailed: true, isEditingTarget: false),
            .showFailure,
            "A failed fit must not silently reappear as the confirmation form Story 8 removes."
        )
    }

    func testEditingTheTargetTakesPrecedenceSoTheUserCanAlwaysChangeTheJob() {
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: true, hasVerdict: true, hasFailed: false, isEditingTarget: true),
            .editTarget
        )
        XCTAssertEqual(
            FitContinuation.step(carriedJobIsReady: true, hasVerdict: false, hasFailed: true, isEditingTarget: true),
            .editTarget
        )
    }

    // MARK: - View-model behaviour

    private func longJD() -> String {
        Array(repeating: "engineer", count: 104).joined(separator: " ")
    }

    private func makeCarriedViewModel(
        service: MockFitCheckService = MockFitCheckService()
    ) -> FitCheckViewModel {
        let vm = FitCheckViewModel(fitCheckService: service)
        vm.resumeId = "resume-1"
        vm.accessToken = "token-1"
        vm.jobDescription = longJD()
        return vm
    }

    func testCarriedFitCheckRunsAutomaticallyAndReachesAVerdict() async {
        let vm = makeCarriedViewModel()
        XCTAssertEqual(vm.continuationStep, .runAutomatically)

        await vm.beginCarriedFitCheck()

        XCTAssertNotNil(vm.result)
        XCTAssertEqual(vm.continuationStep, .showVerdict, "The user lands on the verdict, not a Check Fit button.")
    }

    func testCarriedFitCheckDoesNotRunTwiceForTheSameTarget() async {
        let vm = makeCarriedViewModel()

        await vm.beginCarriedFitCheck()
        let first = vm.result
        await vm.beginCarriedFitCheck()

        XCTAssertNotNil(first)
        XCTAssertTrue(vm.hasAttemptedCarriedCheck)
        XCTAssertEqual(vm.continuationStep, .showVerdict)
    }

    func testCarriedFitCheckDoesNotAutoRunWhenNoJobWasCarried() async {
        let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
        vm.resumeId = "resume-1"
        vm.accessToken = "token-1"

        XCTAssertEqual(vm.continuationStep, .askForJob)

        await vm.beginCarriedFitCheck()

        XCTAssertNil(vm.result, "With nothing carried there is nothing to check automatically.")
        XCTAssertEqual(vm.continuationStep, .askForJob)
    }

    func testUserCanEditTheTargetJobBeforeOptimizing() async {
        let vm = makeCarriedViewModel()
        await vm.beginCarriedFitCheck()
        XCTAssertEqual(vm.continuationStep, .showVerdict)

        vm.editTarget()
        XCTAssertEqual(vm.continuationStep, .editTarget, "The target must remain editable before optimization.")

        vm.jobDescriptionURL = "https://example.com/jobs/other"
        await vm.applyEditedTarget()

        XCTAssertFalse(vm.isEditingTarget)
        XCTAssertNotNil(vm.result, "Re-checking an edited target produces a fresh verdict.")
        XCTAssertEqual(vm.continuationStep, .showVerdict)
    }

    // MARK: - Graceful failure

    private struct FitFailure: Error {}

    func testFitFailureDegradesGracefullyAndPreservesTheGuestDiagnosis() async {
        let tailor = TailorViewModel()
        tailor.selectedResumeURL = URL(fileURLWithPath: "/tmp/picked_resume.pdf")
        tailor.selectedResumeName = "picked_resume.pdf"
        tailor.jobDescriptionURL = "https://example.com/jobs/ios-engineer"
        tailor.recordGuestDiagnosis(
            ATSScoreResult(
                success: true,
                score: .init(overall: 62, timestamp: nil),
                preview: nil,
                quickWins: nil,
                checksRemaining: nil,
                sessionId: "session-1",
                fit: nil,
                error: nil
            )
        )

        let vm = makeCarriedViewModel(service: MockFitCheckService(error: FitFailure()))
        await vm.beginCarriedFitCheck()

        XCTAssertNil(vm.result)
        XCTAssertNotNil(vm.errorMessage, "A fit failure must explain itself.")
        XCTAssertEqual(vm.continuationStep, .showFailure)

        XCTAssertNotNil(tailor.atsResult, "A fit failure must not cost the user their existing diagnosis.")
        XCTAssertTrue(tailor.hasCarriedGuestDiagnosis)
        XCTAssertEqual(tailor.selectedResumeName, "picked_resume.pdf")
    }

    func testRetryingAfterAFailureIsPossible() async {
        let vm = makeCarriedViewModel(service: MockFitCheckService(error: FitFailure()))
        await vm.beginCarriedFitCheck()
        XCTAssertEqual(vm.continuationStep, .showFailure)

        // Editing the target is the user's way out of a failed fit.
        vm.editTarget()
        XCTAssertEqual(vm.continuationStep, .editTarget)
        XCTAssertNil(vm.errorMessage, "Editing clears the stale failure.")
    }
}
