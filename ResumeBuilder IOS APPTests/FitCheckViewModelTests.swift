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

    // MARK: - WP-13 live endpoint smoke (production /api/public/ats-check)

    /// End-to-end against the deployed public ATS endpoint (not mock).
    /// Validates paste-JD → checkFit → verdict → optimize handoff on simulator test host.
    func testLiveFitCheckEndToEndAgainstProduction() async throws {
        let resumeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp13-live-resume-\(UUID().uuidString).pdf")
        try writeTextPDF(Self.sampleResumeText, to: resumeURL)
        defer { try? FileManager.default.removeItem(at: resumeURL) }

        let vm = FitCheckViewModel(fitCheckService: FitCheckService())
        vm.resumeURL = resumeURL
        vm.jobDescription = Self.sampleJobDescription

        await vm.checkFit()

        XCTAssertNil(vm.errorMessage, "Live fit check failed: \(vm.errorMessage ?? "unknown")")
        XCTAssertNotNil(vm.result)
        XCTAssertTrue(vm.isInVerdictState)
        let verdict = try XCTUnwrap(vm.result?.verdict)
        XCTAssertFalse(verdict.scoreNote.isEmpty)
        XCTAssertTrue(
            verdict.scoreNote.localizedCaseInsensitiveContains("estimated")
                || verdict.scoreNote.localizedCaseInsensitiveContains("fit"),
            "EXD-012: score note should stay process-descriptive, got: \(verdict.scoreNote)"
        )

        var optimizeJD: String?
        vm.onOptimize = { optimizeJD = $0 }
        vm.optimizeForThisJob()
        XCTAssertEqual(optimizeJD, Self.sampleJobDescription.trimmingCharacters(in: .whitespacesAndNewlines))

        var skipCalled = false
        vm.onSkip = { skipCalled = true }
        vm.skip()
        XCTAssertTrue(skipCalled)
    }

    func testHebrewFitCheckStringsResolveRTL() {
        LocalizationManager.shared.setLanguage(.hebrew)
        defer { LocalizationManager.shared.setLanguage(.english) }

        XCTAssertEqual(LocalizationManager.shared.layoutDirection, .rightToLeft)

        let title = NSLocalizedString("Check Fit", comment: "")
        let hero = NSLocalizedString("Is this job a fit?", comment: "")
        let note = NSLocalizedString(
            "Estimated fit vs this job. Not affiliated with any ATS vendor. No optimization credit used.",
            comment: ""
        )

        XCTAssertFalse(title.isEmpty)
        XCTAssertFalse(hero.isEmpty)
        XCTAssertFalse(note.isEmpty)
        XCTAssertNotEqual(title, "Check Fit")
        XCTAssertNotEqual(hero, "Is this job a fit?")
    }

    // MARK: - Helpers

    private static let sampleResumeText = """
    Jane Doe — Senior iOS Engineer
    Email: jane.doe@example.com | Phone: 555-0100
    Summary: SwiftUI engineer with 8 years building consumer mobile apps, CI/CD, and App Store releases.
    Experience: Led iOS team shipping resume optimization app with PDF export, ATS scoring, and Hebrew localization.
    Skills: Swift, SwiftUI, Combine, URLSession, PDFKit, XCTest, PostHog analytics, Supabase auth.
    """

    private static let sampleJobDescription: String = {
        Array(
            repeating: """
            Senior iOS Engineer to build SwiftUI features, integrate REST APIs, ship TestFlight builds,
            improve ATS-friendly resume flows, and collaborate with backend on PDF parsing and analytics.
            """,
            count: 4
        ).joined(separator: " ")
    }()

    private func writeTextPDF(_ text: String, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: pageBounds.insetBy(dx: 40, dy: 40), withAttributes: attrs)
        }
        try data.write(to: url)
    }

    private func longJD() -> String {
        Array(repeating: "engineer required skills experience building distributed scalable systems", count: 8).joined(separator: " ")
    }
}
