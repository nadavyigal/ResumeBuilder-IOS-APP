import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ImproveViewModelTests: XCTestCase {
    func testScanUploadUsesAuthenticatedAppStateSession() async {
        let appState = AppState()
        appState.session = AuthSession(
            accessToken: "token",
            refreshToken: "refresh",
            userId: "user-1",
            email: "user@example.com"
        )
        let viewModel = ScanViewModel(uploadService: MockResumeUploadService())
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-upload-test.pdf")
        try? Data("resume".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        viewModel.jobDescription = "iOS Engineer"
        await viewModel.handlePickedFile(url: fileURL, token: nil)

        let input = await viewModel.uploadForOptimization(appState: appState)

        XCTAssertEqual(input?.resumeId, "mock-resume-001")
        XCTAssertEqual(input?.jobDescriptionId, "mock-jd-001")
    }

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
