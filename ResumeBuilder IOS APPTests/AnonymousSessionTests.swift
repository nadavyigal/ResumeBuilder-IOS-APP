import XCTest
@testable import ResumeBuilder_IOS_APP

/// Supabase anonymous sign-in gives a guest a real `auth.uid()`, which is what
/// lets them satisfy `supabase.auth.getUser()` on the API routes and the
/// `auth.uid() = user_id` RLS policies. These tests pin the two properties that
/// make introducing it safe: existing users are not signed out, and a guest
/// holding an anonymous session is still shown the guest UI.
@MainActor
final class AnonymousSessionTests: XCTestCase {

    // MARK: - Keychain back-compatibility

    func testSessionPersistedBeforeAnonymousAuthStillDecodes() throws {
        // The exact shape already sitting in 35 users' Keychains. A non-optional
        // `isAnonymous` would make this throw, and `restoreSession()` swallows
        // decode errors with `try?` — so every existing user would be silently
        // signed out on upgrade.
        let legacy = Data("""
        {"accessToken":"tok","refreshToken":"refresh","userId":"user-1","email":"a@example.com"}
        """.utf8)

        let session = try JSONDecoder().decode(AuthSession.self, from: legacy)

        XCTAssertEqual(session.userId, "user-1")
        XCTAssertNil(session.isAnonymous)
        XCTAssertTrue(session.isAccountSession, "A session with no flag is a real account")
    }

    func testAnonymousSessionRoundTripsThroughEncoding() throws {
        let session = AuthSession(
            accessToken: "tok",
            refreshToken: "refresh",
            userId: "anon-1",
            email: nil,
            isAnonymous: true
        )

        let restored = try JSONDecoder().decode(
            AuthSession.self,
            from: JSONEncoder().encode(session)
        )

        XCTAssertEqual(restored.isAnonymous, true)
        XCTAssertFalse(restored.isAccountSession)
    }

    // MARK: - An anonymous session is a credential, not an account
    //
    // These assert on `AuthSession` rather than on `AppState.isAuthenticated`,
    // which is a one-line delegation to `isAccountSession`. That is deliberate:
    // constructing `AppState()` inside the test host reliably trips the
    // documented malloc crash (`tasks/lessons.md`, 2026-06-25 — same address
    // `0x7ffd41cb7680`, reproduced on untouched `main` while writing these), so
    // a test that builds one never executes and reports a false green. Asserting
    // one level down runs for real and covers the same logic. Do not "fix" these
    // by reintroducing `AppState()`.

    func testAnonymousSessionIsNotAnAccountSession() {
        // The load-bearing assertion. `isAuthenticated` — which is exactly
        // `session?.isAccountSession == true` — drives ~28 UI branches: Profile
        // as a real account, History, "Analyze my resume" instead of "Run Free
        // Match Check". A guest must not get any of that until the funnel
        // design's export cap and registration ask ship with it.
        let anonymous = AuthSession(
            accessToken: "tok",
            refreshToken: "refresh",
            userId: "anon-1",
            email: nil,
            isAnonymous: true
        )

        XCTAssertFalse(anonymous.isAccountSession, "An anonymous session is not an account")
    }

    func testAccountSessionIsAnAccountSession() {
        let account = AuthSession(
            accessToken: "tok",
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@example.com"
        )

        XCTAssertTrue(account.isAccountSession)
    }

    func testExplicitlyNonAnonymousSessionIsAnAccountSession() {
        // Guards the `!= true` comparison: `false` must read as an account, the
        // same as a missing flag, rather than only `nil` doing so.
        let account = AuthSession(
            accessToken: "tok",
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@example.com",
            isAnonymous: false
        )

        XCTAssertTrue(account.isAccountSession)
    }

    // MARK: - Guest analytics stay comparable

    func testAnonymousSessionEventHasItsOwnName() {
        // Fires alongside `guest_mode_started`, never instead of it. Replacing it
        // would break comparability with the 211-guest baseline the funnel work
        // is measured against.
        XCTAssertEqual(AnalyticsEvent.anonymousSessionStarted.name, "anonymous_session_started")
        XCTAssertEqual(AnalyticsEvent.guestModeStarted.name, "guest_mode_started")
    }
}
