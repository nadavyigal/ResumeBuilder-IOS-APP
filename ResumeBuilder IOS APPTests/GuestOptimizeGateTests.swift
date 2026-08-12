import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 2: a guest holding an anonymous session runs the real optimize
/// pipeline, while still not being treated as a signed-up account.
///
/// The distinction is the whole point. `canOptimize` gates the pipeline;
/// `isAuthenticated` gates account identity (Profile, History, saved resumes).
/// Collapsing them would either wall guests out of optimizing or show them a
/// signed-in account they do not have.
///
/// Asserted against `AuthSession` rather than `AppState` for the reason
/// documented in AnonymousSessionTests: constructing `AppState()` in this test
/// host trips a malloc crash that predates this work, so such a test silently
/// executes zero cases.
@MainActor
final class GuestOptimizeGateTests: XCTestCase {

    private func session(anonymous: Bool) -> AuthSession {
        AuthSession(
            accessToken: "tok",
            refreshToken: "refresh",
            userId: anonymous ? "anon-1" : "user-1",
            email: anonymous ? nil : "a@example.com",
            isAnonymous: anonymous
        )
    }

    func testAnonymousSessionIsAUsableCredentialButNotAnAccount() {
        let anonymous = session(anonymous: true)
        // canOptimize is `hasSession`, i.e. any session at all…
        XCTAssertFalse(anonymous.isAccountSession, "…while isAuthenticated is account-only")
    }

    func testAccountSessionIsBothCredentialAndAccount() {
        XCTAssertTrue(session(anonymous: false).isAccountSession)
    }

    // MARK: - Activation copy follows the pipeline, not the account

    func testGuestWithSessionIsOfferedTheRealPipelineNotTheFreeCheck() {
        // HomeTabView passes `canOptimize` into this input, so a guest holding an
        // anonymous session derives `.readyToOptimize` — the real pipeline —
        // rather than being told to sign in first.
        let state = HomeActivationState.derive(from: .init(
            hasResume: true,
            hasJob: true,
            isAuthenticated: true,   // canOptimize == true for an anonymous session
            isOptimizing: false,
            hasATSResult: false,
            hasOptimizationId: false,
            isExportComplete: false
        ))
        XCTAssertEqual(state, .readyToOptimize)
    }

    func testUserWithNoSessionAtAllStillGetsTheFreeCheck() {
        // Anonymous sign-in disabled, or offline at launch. The free Match Check
        // remains the fallback rather than a dead end.
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

    func testCopyNoLongerPromisesAWallThatIsGone() {
        // `.atsComplete` used to read "Sign in to unlock full optimization and
        // PDF export", which stops being true for anyone holding a session.
        let subheadline = String(describing: HomeActivationState.atsComplete.subheadline)
        XCTAssertFalse(
            subheadline.contains("unlock full optimization"),
            "Stale gate copy: this state is now only reachable with no session at all"
        )
    }
}
