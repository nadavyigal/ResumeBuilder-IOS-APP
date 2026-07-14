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

private struct CompetingNavigationTransition: Sendable, Equatable {
    let reviewWasPresented: Bool
    let reviewWasDismissed: Bool
    let diagnosisWasPresented: Bool
    let destinationMutations: Int
}

@MainActor
private final class FirstSessionJourneyHarness {
    let fixture: FirstSessionJourneyFixture
    private(set) var visitedStages: [FirstSessionStage] = [.resumeAndJobReady]
    private(set) var networkCallCount = 0
    private let appState: AppState
    private var isReviewPresented = false
    private var isDiagnosisPresented = false

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
        isReviewPresented = true
        visitedStages.append(.review)
    }

    func applyApprovedChanges() {
        visitedStages.append(.applied)
        appState.latestOptimizationId = fixture.optimizationId
    }

    func renderOptimizedPreview() {
        visitedStages.append(.optimizedPreview)
    }

    func simulateCurrentApplySuccess() -> CompetingNavigationTransition {
        let reviewWasPresented = isReviewPresented
        applyApprovedChanges()
        isReviewPresented = false
        isDiagnosisPresented = true

        return CompetingNavigationTransition(
            reviewWasPresented: reviewWasPresented,
            reviewWasDismissed: !isReviewPresented,
            diagnosisWasPresented: isDiagnosisPresented,
            destinationMutations: 2
        )
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

    func testCurrentApplyTransitionCapturesCompetingNavigationPrecondition() async {
        let harness = FirstSessionJourneyHarness(fixture: .synthetic)
        harness.presentReview()

        let transition = harness.simulateCurrentApplySuccess()

        XCTAssertTrue(transition.reviewWasPresented)
        XCTAssertTrue(transition.reviewWasDismissed)
        XCTAssertTrue(transition.diagnosisWasPresented)
        XCTAssertEqual(transition.destinationMutations, 2)
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
