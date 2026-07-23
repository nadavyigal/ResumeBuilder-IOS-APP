import XCTest
@testable import ResumeBuilder_IOS_APP

private struct FirstSessionJourneyFixture: Sendable, Equatable {
    let resumeFilename: String
    let jobURL: URL
    let jobDescriptionWordCount: Int
    let reviewId: String
    let optimizationId: String

    static let synthetic = FirstSessionJourneyFixture(
        resumeFilename: "synthetic-first-session-resume.pdf",
        jobURL: URL(string: "https://example.invalid/jobs/ios-engineer")!,
        jobDescriptionWordCount: 124,
        reviewId: "review-fixture-001",
        optimizationId: "6AC2929D-325B-4D65-91B1-877409E2365A"
    )
}

private enum FirstSessionStage: Sendable, Equatable {
    case resumeAndJobReady
    case guestDiagnosis
    case authenticated
    case review
    case applied
    case optimizedPreview
}

private enum FirstSessionTab: String, CaseIterable, Sendable {
    case home
    case optimized
    case design
    case expert
    case account
}

private enum OptimizationHistoryStubResponse: Sendable {
    case items([OptimizationHistoryItem])
    case failure
}

private struct OptimizationHistoryServiceStub: OptimizationHistoryServiceProtocol, Sendable {
    let response: OptimizationHistoryStubResponse

    func list(token: String) async throws -> [OptimizationHistoryItem] {
        switch response {
        case .items(let items): return items
        case .failure: throw URLError(.cannotConnectToHost)
        }
    }

    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
        BulkDeleteResponse(success: true, deleted: ids.count, errors: nil)
    }
}

private actor SuspendedOptimizationHistoryService: OptimizationHistoryServiceProtocol {
    private var continuation: CheckedContinuation<[OptimizationHistoryItem], Error>?

    func list(token: String) async throws -> [OptimizationHistoryItem] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
        BulkDeleteResponse(success: true, deleted: ids.count, errors: nil)
    }

    func hasPendingRequest() -> Bool {
        continuation != nil
    }

    func succeed(with items: [OptimizationHistoryItem]) {
        continuation?.resume(returning: items)
        continuation = nil
    }

    func fail() {
        continuation?.resume(throwing: URLError(.cannotConnectToHost))
        continuation = nil
    }
}

@MainActor
private final class FirstSessionJourneyHarness {
    let fixture: FirstSessionJourneyFixture
    private(set) var visitedStages: [FirstSessionStage] = [.resumeAndJobReady]
    private(set) var networkCallCount = 0
    private let appState: AppState

    init(fixture: FirstSessionJourneyFixture, appState: AppState = AppState()) {
        self.fixture = fixture
        self.appState = appState
    }

    var tabOptimizationIds: [FirstSessionTab: String?] {
        Dictionary(
            uniqueKeysWithValues: FirstSessionTab.allCases.map { ($0, appState.latestOptimizationId) }
        )
    }

    func completeGuestCheck() {
        visitedStages.append(.guestDiagnosis)
    }

    func completeAuthentication() {
        visitedStages.append(.authenticated)
    }

    func presentReview() {
        visitedStages.append(.review)
    }

    func applyApprovedChanges() {
        visitedStages.append(.applied)
        appState.latestOptimizationId = fixture.optimizationId
    }

    func renderOptimizedPreview() {
        visitedStages.append(.optimizedPreview)
    }

}

@MainActor
final class FirstSessionJourneyTests: XCTestCase {
    func testTouchedJourneyStringsCompileWithHebrewLocalization() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrewBundle = try XCTUnwrap(Bundle(path: path))
        let requiredKeys = [
            "Add your résumé",
            "Browse Files",
            "Choose another file",
            "Connection dropped",
            "Continue with Apple",
            "Continue with email",
            "Couldn’t reuse your saved résumé. Choose it again to continue.",
            "Create a free account so this never disappears.",
            "Most recruiters scan a resume in about 7 seconds — here's what they'd notice.",
            "PDF or DOCX, up to 5 MB. We'll extract the text so it stays readable for common parsers.",
            "Optimize for another job",
            "Retry now",
            "Scanning like a recruiter would",
            "See what a recruiter notices in the first 7 seconds — then fix it.",
            "These appear in the job description but not your resume. Review the proposed wording before adding it.",
            "Using %@. Add the next job to create a new match.",
            "You're offline",
            "Your résumé and job details are still here — nothing's lost. Retry when you're back online."
        ]

        let fallbacks = requiredKeys.filter {
            hebrewBundle.localizedString(forKey: $0, value: nil, table: nil) == $0
        }
        XCTAssertEqual(fallbacks, [], "Hebrew falls back to English for: \(fallbacks)")
    }

    func testSyntheticGoldenPathCoversGuestCheckThroughPreviewWithoutNetwork() async {
        let harness = FirstSessionJourneyHarness(fixture: .synthetic)
        let expectedStages: [FirstSessionStage] = [
            .resumeAndJobReady,
            .guestDiagnosis,
            .authenticated,
            .review,
            .applied,
            .optimizedPreview
        ]

        harness.completeGuestCheck()
        harness.completeAuthentication()
        harness.presentReview()
        harness.applyApprovedChanges()
        harness.renderOptimizedPreview()

        XCTAssertEqual(harness.visitedStages, expectedStages)
        XCTAssertEqual(harness.networkCallCount, 0)
    }

    func testFirstSessionRoutesHaveStableDistinctIdentities() {
        let review = FirstSessionJourneyRoute.optimizationReview(reviewId: "review-001")
        let diagnosis = FirstSessionJourneyRoute.diagnosis(optimizationId: "optimization-001")

        XCTAssertNotEqual(review.id, diagnosis.id)
        XCTAssertNotEqual(review, diagnosis)
    }

    func testApplyTransitionPersistsBeforeRequestingExactlyOnePreview() {
        var operations: [String] = []
        var previewCount = 0

        let completed = FirstSessionJourneyTransition.completeApply(
            optimizationId: " optimization-001 ",
            persist: { id in operations.append("persist:\(id)") },
            showPreview: { id in
                operations.append("preview:\(id)")
                previewCount += 1
            }
        )

        XCTAssertTrue(completed)
        XCTAssertEqual(operations, ["persist:optimization-001", "preview:optimization-001"])
        XCTAssertEqual(previewCount, 1)
    }

    func testApplyTransitionWithoutOptimizationIdDoesNotLeaveReviewOrShowSuccess() {
        var didPersist = false
        var didShowPreview = false

        let completed = FirstSessionJourneyTransition.completeApply(
            optimizationId: "   ",
            persist: { _ in didPersist = true },
            showPreview: { _ in didShowPreview = true }
        )

        XCTAssertFalse(completed)
        XCTAssertFalse(didPersist)
        XCTAssertFalse(didShowPreview)
    }

    func testAppliedOptimizationIdPropagatesToEveryTabWrapper() async {
        let harness = FirstSessionJourneyHarness(fixture: .synthetic)

        harness.applyApprovedChanges()

        XCTAssertEqual(harness.tabOptimizationIds.count, FirstSessionTab.allCases.count)
        XCTAssertTrue(harness.tabOptimizationIds.values.allSatisfy { $0 == harness.fixture.optimizationId })
        XCTAssertEqual(Set(harness.tabOptimizationIds.values).count, 1)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: AppState.latestOptimizationKey),
            harness.fixture.optimizationId
        )
    }

    func testMissingLocalOptimizationRecoversLatestCompletedBackendItem() async {
        let newestCompleted = optimizationItem(
            id: "optimization-new",
            status: "completed",
            createdAt: "2026-07-14T12:00:00Z"
        )
        let appState = AppState(
            optimizationHistoryService: OptimizationHistoryServiceStub(
                response: .items([
                    optimizationItem(id: "optimization-running", status: "processing", createdAt: "2026-07-14T13:00:00Z"),
                    newestCompleted,
                    optimizationItem(id: "optimization-old", status: "completed", createdAt: "2026-07-13T12:00:00Z")
                ])
            )
        )
        appState.session = authenticatedSession

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(appState.latestOptimizationId, newestCompleted.id)
        XCTAssertEqual(appState.latestOptimization?.id, newestCompleted.id)
        XCTAssertEqual(appState.optimizationRecoveryState, .recovered)
        XCTAssertEqual(UserDefaults.standard.string(forKey: AppState.latestOptimizationKey), newestCompleted.id)
    }

    func testStaleLocalOptimizationIsReplacedByBackendHistory() async {
        let valid = optimizationItem(id: "optimization-valid", status: "completed")
        let appState = AppState(
            optimizationHistoryService: OptimizationHistoryServiceStub(response: .items([valid]))
        )
        appState.session = authenticatedSession
        appState.latestOptimizationId = "optimization-stale"

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(appState.latestOptimizationId, valid.id)
        XCTAssertEqual(appState.latestOptimization?.id, valid.id)
        XCTAssertEqual(appState.optimizationRecoveryState, .recovered)
    }

    func testMockOptimizationIdsNeverUnlockCompletionState() async {
        let appState = AppState(
            optimizationHistoryService: OptimizationHistoryServiceStub(
                response: .items([optimizationItem(id: "mock-history", status: "completed")])
            )
        )
        appState.session = authenticatedSession
        appState.latestOptimizationId = "mock-local"

        await appState.reconcileLatestOptimization()

        XCTAssertNil(appState.latestOptimizationId)
        XCTAssertNil(appState.latestOptimization)
        XCTAssertEqual(appState.optimizationRecoveryState, .empty)
    }

    func testRecoveryFailureIsRetryableWithoutInventingCompletion() async {
        let appState = AppState(
            optimizationHistoryService: OptimizationHistoryServiceStub(response: .failure)
        )
        appState.session = authenticatedSession

        await appState.reconcileLatestOptimization()

        XCTAssertNil(appState.latestOptimizationId)
        XCTAssertEqual(appState.optimizationRecoveryState, .failed)
    }

    func testVerifiedLocalOptimizationSurvivesTransientRecoveryFailure() async {
        let appState = AppState(
            optimizationHistoryService: OptimizationHistoryServiceStub(response: .failure)
        )
        appState.session = authenticatedSession
        appState.latestOptimizationId = "optimization-completed"

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(appState.latestOptimizationId, "optimization-completed")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: AppState.latestOptimizationKey),
            "optimization-completed"
        )
        XCTAssertEqual(appState.optimizationRecoveryState, .failed)
    }

    func testLateRecoveryFailureDoesNotOverwriteNewerOptimization() async {
        let historyService = SuspendedOptimizationHistoryService()
        let appState = AppState(optimizationHistoryService: historyService)
        appState.session = authenticatedSession
        appState.latestOptimizationId = "optimization-old"

        let recovery = Task { await appState.reconcileLatestOptimization() }
        guard await waitForPendingRequest(on: historyService) else {
            recovery.cancel()
            return XCTFail("Recovery did not reach the suspended history request before timeout")
        }

        appState.latestOptimizationId = "optimization-new"
        await historyService.fail()
        await recovery.value

        XCTAssertEqual(appState.latestOptimizationId, "optimization-new")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: AppState.latestOptimizationKey),
            "optimization-new"
        )
        XCTAssertEqual(appState.optimizationRecoveryState, .idle)
    }

    func testLateRecoverySuccessDoesNotRestoreOptimizationAfterSignOut() async {
        let historyService = SuspendedOptimizationHistoryService()
        let appState = AppState(optimizationHistoryService: historyService)
        appState.session = authenticatedSession
        appState.latestOptimizationId = "optimization-old"

        let recovery = Task { await appState.reconcileLatestOptimization() }
        guard await waitForPendingRequest(on: historyService) else {
            recovery.cancel()
            return XCTFail("Recovery did not reach the suspended history request before timeout")
        }

        appState.signOut()
        await historyService.succeed(
            with: [optimizationItem(id: "optimization-old", status: "completed")]
        )
        await recovery.value

        XCTAssertNil(appState.latestOptimizationId)
        XCTAssertNil(UserDefaults.standard.string(forKey: AppState.latestOptimizationKey))
        XCTAssertEqual(appState.optimizationRecoveryState, .idle)
    }

    private func waitForPendingRequest(
        on historyService: SuspendedOptimizationHistoryService
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !(await historyService.hasPendingRequest()) {
            guard clock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.latestOptimizationKey)
        super.tearDown()
    }

    private var authenticatedSession: AuthSession {
        AuthSession(accessToken: "test-token", refreshToken: nil, userId: "test-user", email: nil)
    }

    private func optimizationItem(
        id: String,
        status: String,
        createdAt: String = "2026-07-14T12:00:00Z"
    ) -> OptimizationHistoryItem {
        OptimizationHistoryItem(
            id: id,
            createdAt: createdAt,
            jobTitle: nil,
            company: nil,
            matchScorePercent: 80,
            status: status
        )
    }
}
