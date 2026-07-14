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

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.latestOptimizationKey)
        super.tearDown()
    }
}
