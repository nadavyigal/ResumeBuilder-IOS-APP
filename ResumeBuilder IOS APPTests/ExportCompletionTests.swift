import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ExportCompletionTests: XCTestCase {
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
