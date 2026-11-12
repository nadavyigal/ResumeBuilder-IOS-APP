import XCTest
@testable import ResumeBuilder_IOS_APP

/// Tester call, 2026-11-12: "Check my fit" three times on the same résumé and
/// job ran three full AI optimizations. A guest's checks also count against the
/// free limit (web `anonymous-optimize-limit`), and accepting each new review
/// mints and bills another optimization. These tests pin the reuse.
@MainActor
final class RepeatCheckReuseTests: XCTestCase {

    private var fileURL: URL!
    /// What the server says about the reused optimization: false is a 404.
    private var optimizationExists = true

    override func setUp() async throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("repeat-check-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4 resume A".utf8).write(to: fileURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func makeModel(optimizer: ReviewOptimizerSpy, uploads: CountingUploader = CountingUploader()) -> TailorViewModel {
        let model = TailorViewModel(
            optimizationService: optimizer,
            uploader: uploads.upload,
            track: { _ in },
            optimizationStillExists: { [unowned self] _, _ in self.optimizationExists }
        )
        model.selectedResumeURL = fileURL
        model.selectedResumeName = "resume.pdf"
        model.jobDescriptionURL = "https://www.linkedin.com/jobs/view/4012345678"
        return model
    }

    private func appState(_ userId: String = "user-1") -> AppState {
        let state = AppState(authClient: ReuseAuthClient())
        state.session = AuthSession(accessToken: "token", refreshToken: nil, userId: userId, email: nil, isAnonymous: false)
        return state
    }

    func testSameFileAndJobDoesNotRunASecondOptimization() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        XCTAssertEqual(model.reviewId, "review-1")

        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 1, "the repeat reuses the finished check")
        XCTAssertEqual(model.reviewId, "review-1")
        XCTAssertNil(model.reusedOptimizationId, "not accepted yet, so the review opens again")
        XCTAssertNil(model.errorMessage)
    }

    func testRepeatAfterAcceptOpensTheAcceptedOptimization() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        model.recordAcceptedCheck(reviewId: "review-1", optimizationId: "opt-accepted")
        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 1)
        XCTAssertEqual(model.reusedOptimizationId, "opt-accepted")
        XCTAssertNil(model.reviewId, "the review must not be offered for a second accept")
    }

    /// Reviewer, 2026-11-12: the accepted optimization was deleted from history,
    /// so reopening it would land on a dead id. Run a fresh check instead.
    func testDeletedOptimizationRunsAFreshCheck() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        model.recordAcceptedCheck(reviewId: "review-1", optimizationId: "opt-accepted")
        optimizationExists = false
        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 2)
        XCTAssertNil(model.reusedOptimizationId)
        XCTAssertEqual(model.reviewId, "review-2")
    }

    func testDifferentJobRunsANewCheck() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        model.jobDescriptionURL = "https://www.linkedin.com/jobs/view/4099999999"
        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 2)
        XCTAssertEqual(model.reviewId, "review-2")
    }

    func testNewFileUnderTheSameNameRunsANewCheck() async throws {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        try Data("%PDF-1.4 resume B, edited".utf8).write(to: fileURL)
        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 2)
    }

    func testAnotherAccountRunsANewCheck() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)

        await model.optimize(appState: appState("user-1"))
        model.resetUploadCache() // MainTabViewV2 does this when the account changes
        await model.optimize(appState: appState("user-2"))

        XCTAssertEqual(optimizer.callCount, 2)
    }

    func testAFailedCheckIsNotReused() async {
        let optimizer = ReviewOptimizerSpy(failFirst: true)
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        XCTAssertNotNil(model.errorMessage)
        await model.optimize(appState: state)

        XCTAssertEqual(optimizer.callCount, 2)
        XCTAssertEqual(model.reviewId, "review-2")
    }

    func testAcceptForAnotherReviewIsIgnored() async {
        let optimizer = ReviewOptimizerSpy()
        let model = makeModel(optimizer: optimizer)
        let state = appState()

        await model.optimize(appState: state)
        model.recordAcceptedCheck(reviewId: "some-other-review", optimizationId: "opt-x")
        await model.optimize(appState: state)

        XCTAssertNil(model.reusedOptimizationId)
        XCTAssertEqual(model.reviewId, "review-1")
    }

    func testUnreadableFileNeverReuses() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).pdf")
        let job = JobInputPolicy.evaluate(description: "", urlString: "https://www.linkedin.com/jobs/view/4012345678")
        XCTAssertNil(TailorViewModel.checkInputKey(fileURL: missing, jobInput: job))
    }
}

@MainActor
private final class CountingUploader {
    private(set) var count = 0
    var upload: TailorViewModel.ResumeUploader {
        { _, _, _, _ in
            self.count += 1
            let json = #"{"success":true,"resumeId":"resume-\#(self.count)","jobDescriptionId":"job-\#(self.count)"}"#
            return try JSONDecoder().decode(ResumeUploadResponse.self, from: Data(json.utf8))
        }
    }
}

/// Answers like the review-based flow: a new review id per run.
private final class ReviewOptimizerSpy: ResumeOptimizationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let failFirst: Bool

    init(failFirst: Bool = false) { self.failFirst = failFirst }

    var callCount: Int { lock.lock(); defer { lock.unlock() }; return calls }

    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
        let n: Int = { lock.lock(); defer { lock.unlock() }; calls += 1; return calls }()
        if failFirst && n == 1 { throw APIClientError.serverError(status: 503, message: "Service unavailable") }
        let json = #"{"success":true,"reviewId":"review-\#(n)"}"#
        return try JSONDecoder().decode(OptimizeResponse.self, from: Data(json.utf8))
    }

    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse {
        throw URLError(.unsupportedURL)
    }

    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool { false }
}

private final class ReuseAuthClient: AuthClient, @unchecked Sendable {
    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func refreshSession(refreshToken: String) async throws -> AuthSession { throw URLError(.notConnectedToInternet) }
    func deleteAccount(accessToken: String) async throws {}
}
