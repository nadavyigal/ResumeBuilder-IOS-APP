import XCTest
import UIKit
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ExportCompletionTests: XCTestCase {
    func testShareSheetReportsSupportedOutcomesOncePerPresentation() {
        for (completed, error, expected) in [
            (true, nil, ShareOutcome.completed),
            (false, nil, ShareOutcome.cancelled),
            (false, NSError(domain: "synthetic", code: 1), ShareOutcome.failed),
            (true, NSError(domain: "synthetic", code: 1), ShareOutcome.failed)
        ] {
            var outcomes: [ShareOutcome] = []
            let coordinator = ShareSheet.Coordinator { outcomes.append($0) }
            let controller = UIActivityViewController(activityItems: ["test"], applicationActivities: nil)
            coordinator.connect(to: controller)
            controller.completionWithItemsHandler?(nil, completed, nil, error)
            controller.completionWithItemsHandler?(nil, completed, nil, error)
            XCTAssertEqual(outcomes, [expected])
        }
    }

    func testRepeatedSharePresentationGetsIndependentCompletion() {
        var outcomes: [ShareOutcome] = []
        for _ in 0..<2 {
            let coordinator = ShareSheet.Coordinator { outcomes.append($0) }
            let controller = UIActivityViewController(activityItems: ["test"], applicationActivities: nil)
            coordinator.connect(to: controller)
            controller.completionWithItemsHandler?(nil, true, nil, nil)
        }
        XCTAssertEqual(outcomes, [.completed, .completed])
    }

    func testShareOutcomeAnalyticsDoesNotChangeArtifactReadyContract() {
        for outcome in [ShareOutcome.completed, .cancelled, .failed] {
            let event = AnalyticsEvent.exportShareResult(optimizationId: "opt-share", outcome: outcome.rawValue)
            XCTAssertEqual(event.name, "export_share_result")
            XCTAssertEqual(event.properties, ["optimization_id": "opt-share", "outcome": outcome.rawValue])
        }
        XCTAssertEqual(AnalyticsEvent.exportSuccess(optimizationId: "opt-share").name, "export_success")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.exportCompletionKey)
        UserDefaults.standard.removeObject(forKey: AppState.latestOptimizationKey)
        super.tearDown()
    }

    func testMarkExportCompletePersistsByOptimizationId() {
        let appState = AppState()
        appState.markExportComplete(for: "opt-123")
        XCTAssertTrue(appState.isExportComplete(for: "opt-123"))
        XCTAssertFalse(appState.isExportComplete(for: "opt-456"))

        let reloaded = AppState()
        reloaded.bootstrap()
        XCTAssertTrue(reloaded.isExportComplete(for: "opt-123"))
    }

    func testSignOutClearsExportCompletion() {
        let appState = AppState()
        appState.markExportComplete(for: "opt-123")
        appState.signOut()
        XCTAssertNil(appState.exportCompletion)
        XCTAssertFalse(appState.isExportComplete(for: "opt-123"))
    }

    func testReviewPromptRequiresSuccessfulExport() {
        let store = InMemoryReviewPromptVersionStore()
        let gate = ReviewPromptGate(
            store: store,
            appVersion: "1.4.6",
            isInternalTester: false
        )

        XCTAssertFalse(gate.claimAfterSuccessfulExport(hasCompletedExport: false))
        XCTAssertNil(store.requestedVersion())
    }

    func testReviewPromptExcludesInternalTesters() {
        let store = InMemoryReviewPromptVersionStore()
        let gate = ReviewPromptGate(
            store: store,
            appVersion: "1.4.6",
            isInternalTester: true
        )

        XCTAssertFalse(gate.claimAfterSuccessfulExport(hasCompletedExport: true))
        XCTAssertNil(store.requestedVersion())
    }

    func testReviewPromptClaimsOncePerVersionAndAllowsLaterVersion() {
        let store = InMemoryReviewPromptVersionStore()
        let currentGate = ReviewPromptGate(
            store: store,
            appVersion: "1.4.6",
            isInternalTester: false
        )

        XCTAssertTrue(currentGate.claimAfterSuccessfulExport(hasCompletedExport: true))
        XCTAssertFalse(currentGate.claimAfterSuccessfulExport(hasCompletedExport: true))

        let nextGate = ReviewPromptGate(
            store: store,
            appVersion: "1.4.7",
            isInternalTester: false
        )
        XCTAssertTrue(nextGate.claimAfterSuccessfulExport(hasCompletedExport: true))
        XCTAssertEqual(store.requestedVersion(), "1.4.7")
    }

    func testReviewPromptVersionPersistsThroughKeychainStoreRecreation() throws {
        let service = "com.resumely.tests.review-prompt.\(UUID().uuidString)"
        let account = "requested-version"
        defer {
            KeychainStore.shared.remove(service: service, account: account)
        }

        let firstStore = KeychainReviewPromptVersionStore(service: service, account: account)
        try firstStore.saveRequestedVersion("1.4.6")

        let recreatedStore = KeychainReviewPromptVersionStore(service: service, account: account)
        XCTAssertEqual(recreatedStore.requestedVersion(), "1.4.6")
    }

    func testReviewPromptDoesNotIssueWhenDurableClaimFails() {
        let gate = ReviewPromptGate(
            store: FailingReviewPromptVersionStore(),
            appVersion: "1.4.6",
            isInternalTester: false
        )

        XCTAssertFalse(gate.claimAfterSuccessfulExport(hasCompletedExport: true))
    }
}

@MainActor
private final class InMemoryReviewPromptVersionStore: ReviewPromptVersionStoring {
    private var version: String?

    func requestedVersion() -> String? {
        version
    }

    func saveRequestedVersion(_ version: String) throws {
        self.version = version
    }
}

@MainActor
private struct FailingReviewPromptVersionStore: ReviewPromptVersionStoring {
    func requestedVersion() -> String? {
        nil
    }

    func saveRequestedVersion(_ version: String) throws {
        throw CocoaError(.fileWriteUnknown)
    }
}
