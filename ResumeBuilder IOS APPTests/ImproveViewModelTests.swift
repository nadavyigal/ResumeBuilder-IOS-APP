import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ImproveViewModelTests: XCTestCase {
    /// Founder decision 2026-10-28: a lower rescan shows the lower score, with
    /// the higher one as "Previous best", matching the Optimized tab (Sonnet on #222).
    func testALowerRescanShowsTheMeasuredScoreAndThePreviousBest() async {
        let viewModel = ImproveViewModel(
            resumeId: "resume_1",
            jobDescription: "iOS Engineer",
            optimizationId: "opt_1",
            initialAnalysis: ResumeAnalysis(overall: 72, ats: 72, content: 60, design: 60, missingKeywords: []),
            analysisService: RescanStubService(original: 29, optimized: 64),
            optimizationService: MockResumeOptimizationService()
        )

        await viewModel.rescanATS(token: "tok")

        XCTAssertEqual(viewModel.analysis?.overall, 64)
        XCTAssertEqual(viewModel.previousBestScore, 72)
        XCTAssertEqual(viewModel.previousBestLabel, "Previous best: 72")
    }

    func testAHigherRescanHasNoPreviousBest() async {
        let viewModel = ImproveViewModel(
            resumeId: "resume_1",
            jobDescription: "iOS Engineer",
            optimizationId: "opt_1",
            initialAnalysis: ResumeAnalysis(overall: 60, ats: 60, content: 60, design: 60, missingKeywords: []),
            analysisService: RescanStubService(original: 29, optimized: 75),
            optimizationService: MockResumeOptimizationService()
        )

        await viewModel.rescanATS(token: "tok")

        XCTAssertEqual(viewModel.analysis?.overall, 75)
        XCTAssertNil(viewModel.previousBestScore)
    }

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

/// Answers every rescan with fixed original and optimized scores.
private struct RescanStubService: ResumeAnalysisServiceProtocol {
    let original: Int
    let optimized: Int

    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        ResumeAnalysis(overall: 0, ats: 0, content: 0, design: 0, missingKeywords: [])
    }
    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement] { [] }
    func rescan(optimizationId: String, token: String) async throws -> ATSRescanResponse {
        let json = #"{"success":true,"scores":{"original":\#(original),"optimized":\#(optimized)}}"#
        return try JSONDecoder().decode(ATSRescanResponse.self, from: Data(json.utf8))
    }
}
