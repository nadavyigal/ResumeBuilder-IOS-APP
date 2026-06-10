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
}
