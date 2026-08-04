import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ImproveViewModelTests: XCTestCase {
    // `testScanUploadUsesAuthenticatedAppStateSession` was removed on 2026-08-04
    // with `ScanViewModel`. It asserted that the Scan screen's upload used the
    // session on `AppState` rather than a passed token; the equivalent guarantee
    // on the live path is `TailorViewModel.ensureUploadedResumeForCurrentJob`,
    // which reads `appState.session` through `callWithFreshToken`.

    func testImproveOptimizeUsesAuthenticatedAppStateSession() async {
        let appState = AppState()
        appState.session = AuthSession(
            accessToken: "token",
            refreshToken: "refresh",
            userId: "user-1",
            email: "user@example.com"
        )
        let viewModel = ImproveViewModel(
            resumeId: "resume_1",
            jobDescriptionId: "jd_test_1",
            jobDescription: "iOS Engineer",
            analysisService: MockResumeAnalysisService(),
            optimizationService: MockResumeOptimizationService()
        )

        let result = await viewModel.optimize(appState: appState)

        XCTAssertEqual(result?.optimizationId, "mock-opt-001")
        XCTAssertEqual(result?.sections.count, 3)
    }

    func testOptimizeReturnsErrorWhenTokenMissing() async {
        let viewModel = ImproveViewModel(
            resumeId: "resume_1",
            jobDescription: "iOS Engineer",
            analysisService: MockResumeAnalysisService(),
            optimizationService: MockResumeOptimizationService()
        )

        let result = await viewModel.optimize(token: nil)
        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, ResumeOptimizationError.missingToken.localizedDescription)
    }

    func testOptimizeReturnsOptimizationIdAndSections() async {
        let viewModel = ImproveViewModel(
            resumeId: "resume_1",
            jobDescriptionId: "jd_test_1",
            jobDescription: "iOS Engineer",
            analysisService: MockResumeAnalysisService(),
            optimizationService: MockResumeOptimizationService()
        )

        let result = await viewModel.optimize(token: "token")
        XCTAssertEqual(result.flatMap(\.optimizationId), "mock-opt-001")
        XCTAssertEqual(result?.sections.count, 3)
    }
}
