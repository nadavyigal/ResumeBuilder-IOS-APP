import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class RuntimeServicesTests: XCTestCase {
    func testRuntimeServicesResolveRealServices() {
        XCTAssertTrue(RuntimeServices.resumeUploadService() is ResumeUploadService)
        XCTAssertTrue(RuntimeServices.resumeAnalysisService() is ResumeAnalysisService)
        XCTAssertTrue(RuntimeServices.resumeOptimizationService() is ResumeOptimizationService)
        XCTAssertTrue(RuntimeServices.resumeExportService() is ResumeExportService)
        XCTAssertTrue(RuntimeServices.recentExportsService() is RecentExportsService)
        XCTAssertTrue(RuntimeServices.optimizationHistoryService() is OptimizationHistoryService)
        XCTAssertTrue(RuntimeServices.resumeLibraryService() is ResumeLibraryService)
        XCTAssertTrue(RuntimeServices.resumeDesignService() is ResumeDesignService)
    }

    func testBootstrapClearsPersistedMockOptimizationId() async {
        UserDefaults.standard.set("mock-opt-001", forKey: AppState.latestOptimizationKey)

        let appState = AppState()
        appState.bootstrap()

        XCTAssertNil(appState.latestOptimizationId)
        XCTAssertNil(UserDefaults.standard.string(forKey: AppState.latestOptimizationKey))
    }

    func testBootstrapKeepsPersistedRealOptimizationId() async {
        let realId = "b8f5608f-0f9b-45af-b893-dc0a18d6b20a"
        UserDefaults.standard.set(realId, forKey: AppState.latestOptimizationKey)

        let appState = AppState()
        appState.bootstrap()

        XCTAssertEqual(appState.latestOptimizationId, realId)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.latestOptimizationKey)
        super.tearDown()
    }
}
