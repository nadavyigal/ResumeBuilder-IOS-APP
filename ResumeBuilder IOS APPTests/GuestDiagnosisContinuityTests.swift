import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 7 — preserve guest context through authentication.
///
/// `MainActor`-isolated to match `JobInputPolicy`, which the fingerprint builds on.
@MainActor
final class GuestDiagnosisContinuityTests: XCTestCase {

    private let resumeURL = URL(fileURLWithPath: "/tmp/picked_resume.pdf")
    private let otherResumeURL = URL(fileURLWithPath: "/tmp/other_resume.pdf")
    private let jobURL = "https://example.com/jobs/ios-engineer"

    private func fingerprint(
        resume: URL?,
        description: String = "",
        urlString: String = ""
    ) -> GuestDiagnosisContinuity.InputFingerprint? {
        GuestDiagnosisContinuity.InputFingerprint.make(
            resumeURL: resume,
            description: description,
            urlString: urlString
        )
    }

    // MARK: - Fingerprint identity

    func testFingerprintRequiresBothAResumeAndReadyJobInput() {
        XCTAssertNil(fingerprint(resume: nil, urlString: jobURL), "No résumé means no diagnosis to preserve.")
        XCTAssertNil(fingerprint(resume: resumeURL), "Empty job input is not ready, so nothing is fingerprinted.")
        XCTAssertNil(
            fingerprint(resume: resumeURL, description: "Too short to count."),
            "A sub-threshold paste is not ready job input."
        )
        XCTAssertNotNil(fingerprint(resume: resumeURL, urlString: jobURL))
    }

    /// The fingerprint must not carry résumé or job *content* — only identity.
    func testFingerprintCarriesNoJobDescriptionContentWhenURLIsUsed() {
        let fp = fingerprint(resume: resumeURL, urlString: jobURL)
        XCTAssertEqual(fp?.resumePath, resumeURL.path)
        XCTAssertEqual(fp?.normalizedURL, jobURL)
        XCTAssertEqual(fp?.normalizedDescription, "", "URL-only input must not synthesize description content.")
    }

    // MARK: - Continuity decisions

    func testUnchangedInputsCarryTheGuestDiagnosisThroughSignup() {
        let captured = fingerprint(resume: resumeURL, urlString: jobURL)
        let current = fingerprint(resume: resumeURL, urlString: jobURL)

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: captured, current: current),
            .carryForward
        )
    }

    func testWhitespaceOnlyEditDoesNotInvalidateTheDiagnosis() {
        let captured = fingerprint(resume: resumeURL, urlString: jobURL)
        let current = fingerprint(resume: resumeURL, urlString: "  \(jobURL)  ")

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: captured, current: current),
            .carryForward,
            "Normalization means cosmetic whitespace is not a real input change."
        )
    }

    func testChangedJobLinkInvalidatesTheDiagnosis() {
        let captured = fingerprint(resume: resumeURL, urlString: jobURL)
        let current = fingerprint(resume: resumeURL, urlString: "https://example.com/jobs/android-engineer")

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: captured, current: current),
            .invalidateDiagnosis
        )
    }

    func testChangedResumeInvalidatesTheDiagnosis() {
        let captured = fingerprint(resume: resumeURL, urlString: jobURL)
        let current = fingerprint(resume: otherResumeURL, urlString: jobURL)

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: captured, current: current),
            .invalidateDiagnosis
        )
    }

    func testClearingInputsAfterADiagnosisInvalidatesIt() {
        let captured = fingerprint(resume: resumeURL, urlString: jobURL)

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: captured, current: nil),
            .invalidateDiagnosis
        )
    }

    func testNoCapturedDiagnosisIsSimplyNothingToPreserve() {
        let current = fingerprint(resume: resumeURL, urlString: jobURL)

        XCTAssertEqual(
            GuestDiagnosisContinuity.decide(capturedAt: nil, current: current),
            .noDiagnosis
        )
    }

    // MARK: - Post-auth step

    func testCarriedDiagnosisDoesNotRequireAnalyzeAfterSignup() {
        XCTAssertEqual(
            GuestDiagnosisContinuity.postAuthStep(for: .carryForward),
            .continueToOptimize,
            "Unchanged inputs must never force the user to re-run the analysis they already ran as a guest."
        )
    }

    func testInvalidatedOrAbsentDiagnosisFallsBackToAnalyze() {
        XCTAssertEqual(GuestDiagnosisContinuity.postAuthStep(for: .invalidateDiagnosis), .runAnalysis)
        XCTAssertEqual(GuestDiagnosisContinuity.postAuthStep(for: .noDiagnosis), .runAnalysis)
    }

    /// The prompt forbids auto-starting optimization after authentication.
    func testPostAuthStepNeverAutoStartsOptimization() {
        for decision in [
            GuestDiagnosisContinuity.Decision.carryForward,
            .invalidateDiagnosis,
            .noDiagnosis,
        ] {
            let step = GuestDiagnosisContinuity.postAuthStep(for: decision)
            XCTAssertTrue(
                step == .continueToOptimize || step == .runAnalysis,
                "Post-auth must only ever offer a user-initiated step, never start optimization itself."
            )
        }
    }
}

// MARK: - View-model level continuity

@MainActor
final class TailorViewModelGuestContinuityTests: XCTestCase {

    private let resumeURL = URL(fileURLWithPath: "/tmp/picked_resume.pdf")
    private let jobURL = "https://example.com/jobs/ios-engineer"

    private func makeATSResult() -> ATSScoreResult {
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
    }

    /// Simulates what `runFreeATS` records on success, without a network call.
    private func makeGuestDiagnosedViewModel() -> TailorViewModel {
        let vm = TailorViewModel()
        vm.selectedResumeURL = resumeURL
        vm.selectedResumeName = "picked_resume.pdf"
        vm.jobDescriptionURL = jobURL
        vm.recordGuestDiagnosis(makeATSResult())
        return vm
    }

    func testGuestDiagnosisSurvivesAuthenticationWhenInputsAreUnchanged() {
        let vm = makeGuestDiagnosedViewModel()

        vm.invalidateGuestDiagnosisIfInputsChanged()

        XCTAssertNotNil(vm.atsResult, "Signing in must not discard the guest diagnosis.")
        XCTAssertEqual(vm.selectedResumeName, "picked_resume.pdf")
        XCTAssertEqual(vm.jobDescriptionURL, jobURL)
        XCTAssertTrue(vm.hasCarriedGuestDiagnosis)
    }

    func testChangingTheJobInvalidatesOnlyTheDiagnosisAndKeepsTheResume() {
        let vm = makeGuestDiagnosedViewModel()

        vm.jobDescriptionURL = "https://example.com/jobs/android-engineer"
        vm.invalidateGuestDiagnosisIfInputsChanged()

        XCTAssertNil(vm.atsResult, "A changed job must invalidate the dependent diagnosis.")
        XCTAssertEqual(vm.selectedResumeURL, resumeURL, "The résumé selection is not dependent on the job.")
        XCTAssertEqual(vm.selectedResumeName, "picked_resume.pdf")
        XCTAssertEqual(
            vm.jobDescriptionURL,
            "https://example.com/jobs/android-engineer",
            "The user's new job input must survive invalidation."
        )
        XCTAssertFalse(vm.hasCarriedGuestDiagnosis)
    }

    func testCancellingAuthLeavesTheGuestDiagnosisIntact() {
        let vm = makeGuestDiagnosedViewModel()

        // Auth cancellation changes no input; the continuity check runs on every auth transition.
        vm.invalidateGuestDiagnosisIfInputsChanged()
        vm.invalidateGuestDiagnosisIfInputsChanged()

        XCTAssertNotNil(vm.atsResult, "Cancelling sign-in must return to the intact guest diagnosis.")
        XCTAssertTrue(vm.hasCarriedGuestDiagnosis)
    }

    func testRecordingANewDiagnosisRebaselinesTheFingerprint() {
        let vm = makeGuestDiagnosedViewModel()

        vm.jobDescriptionURL = "https://example.com/jobs/android-engineer"
        vm.invalidateGuestDiagnosisIfInputsChanged()
        XCTAssertNil(vm.atsResult)

        vm.recordGuestDiagnosis(makeATSResult())
        vm.invalidateGuestDiagnosisIfInputsChanged()

        XCTAssertNotNil(vm.atsResult, "A fresh diagnosis must be valid for the inputs it was computed from.")
        XCTAssertTrue(vm.hasCarriedGuestDiagnosis)
    }
}
