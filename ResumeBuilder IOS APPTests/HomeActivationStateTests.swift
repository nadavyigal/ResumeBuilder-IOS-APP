import XCTest
@testable import ResumeBuilder_IOS_APP

final class HomeActivationStateTests: XCTestCase {
    func testNoResumeWhenEmpty() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: false,
            hasJob: false,
            isAuthenticated: false,
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .noResume)
    }

    func testResumeNoJob() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: false,
            isAuthenticated: false,
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .resumeNoJob)
    }

    func testReadyForFreeATSForGuest() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: false,
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .readyForFreeATS)
    }

    func testReadyToOptimizeForAuthenticated() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: true,
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .readyToOptimize)
    }

    func testOptimizingTakesPrecedence() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: true,
            isOptimizing: true,
            hasATSResult: false,
            hasOptimizationId: true,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .optimizing)
    }

    func testExportComplete() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: true,
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: true,
            isExportComplete: true
        ))
        XCTAssertEqual(state, .exportComplete)
    }

    func testATSCompleteForGuest() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: false,
            isOptimizing: false,
            hasATSResult: true,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .atsComplete)
    }

    /// Guest sees ATS score, then signs in — should advance to readyToOptimize,
    /// not stay on atsComplete (atsComplete is a guest-only state).
    func testAuthenticatedAfterATSResult() {
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: true,
            isOptimizing: false,
            hasATSResult: true,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .readyToOptimize)
    }
}
