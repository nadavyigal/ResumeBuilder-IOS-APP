import XCTest
@testable import ResumeBuilder_IOS_APP

// `AuthSession` is main-actor isolated by the app target's default isolation.
@MainActor
final class AuthServiceResponseTests: XCTestCase {
    /// GoTrue can answer a token request without a refresh token; the app must refuse to
    /// build a session it could never refresh.
    func testGoTrueResponseWithoutRefreshTokenIsRejected() throws {
        let json = """
        {
          "access_token": "access",
          "refresh_token": null,
          "user": { "id": "user-1", "email": "a@b.com" }
        }
        """

        let decoded = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8))

        XCTAssertThrowsError(try decoded.makeSession()) { error in
            guard case AuthServiceError.invalidResponse = error else {
                return XCTFail("Expected .invalidResponse, got \(error)")
            }
        }
    }

    func testGoTrueResponseWithRefreshTokenBuildsSession() throws {
        let json = """
        {
          "access_token": "access",
          "refresh_token": "refresh",
          "user": { "id": "user-1", "email": "a@b.com" }
        }
        """

        let session = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8)).makeSession()

        XCTAssertEqual(session.accessToken, "access")
        XCTAssertEqual(session.refreshToken, "refresh")
        XCTAssertEqual(session.userId, "user-1")
        XCTAssertEqual(session.email, "a@b.com")
    }

    // MARK: - is_anonymous survives refresh
    //
    // `refreshSession` persists exactly what `makeSession()` returns, and
    // `restoreSession()` reads it back with `JSONDecoder`. Before this was fixed,
    // `makeSession()` dropped `user.is_anonymous`, so the first token refresh
    // saved an anonymous guest as a real account and `AppState.isAuthenticated`
    // turned true for them. These go through the same encode/decode the Keychain
    // does, so they pin the saved-and-restored state, not just the in-memory one.

    /// GoTrue's real refresh payload for an anonymous user.
    func testRefreshingAnonymousSessionStaysAnonymous() throws {
        let json = """
        {
          "access_token": "access-2",
          "refresh_token": "refresh-2",
          "user": { "id": "anon-1", "email": "", "is_anonymous": true }
        }
        """

        let refreshed = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8)).makeSession()
        let restored = try Self.persistAndRestore(refreshed)

        XCTAssertEqual(refreshed.isAnonymous, true)
        XCTAssertEqual(restored.isAnonymous, true)
        XCTAssertFalse(restored.isAccountSession, "A refreshed guest must not restore as an account")
    }

    func testRefreshingAccountSessionStaysAccount() throws {
        let json = """
        {
          "access_token": "access-2",
          "refresh_token": "refresh-2",
          "user": { "id": "user-1", "email": "a@b.com", "is_anonymous": false }
        }
        """

        let refreshed = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8)).makeSession()
        let restored = try Self.persistAndRestore(refreshed)

        XCTAssertEqual(refreshed.isAnonymous, false)
        XCTAssertEqual(restored.isAnonymous, false)
        XCTAssertTrue(restored.isAccountSession)
    }

    /// Older GoTrue versions omit the field. Absent keeps meaning "a real account",
    /// the same rule `AuthSession` applies to sessions saved before anonymous auth.
    func testResponseWithoutIsAnonymousDecodesAsAccount() throws {
        let json = """
        {
          "access_token": "access",
          "refresh_token": "refresh",
          "user": { "id": "user-1", "email": "a@b.com" }
        }
        """

        let decoded = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8))
        let session = try Self.persistAndRestore(decoded.makeSession())

        XCTAssertNil(decoded.user.is_anonymous)
        XCTAssertNil(session.isAnonymous)
        XCTAssertTrue(session.isAccountSession)
    }

    /// The same encode/decode `AuthService.persist` and `restoreSession()` use.
    private static func persistAndRestore(_ session: AuthSession) throws -> AuthSession {
        try JSONDecoder().decode(AuthSession.self, from: JSONEncoder().encode(session))
    }

    // MARK: - Restore repair from the access token's is_anonymous claim
    //
    // Sessions saved by builds before the refresh fix lost the flag and read as
    // accounts. The access token saved with them still carries Supabase's
    // `is_anonymous` claim, so restore corrects them before `bootstrap()` uses
    // the session. The JWT is the source of truth only in one direction: it can
    // mark a session anonymous, never turn a real account into a guest.

    func testRestoredSessionMissingFlagWithAnonymousClaimRestoresAsAnonymous() {
        let saved = AuthSession(
            accessToken: Self.makeJWT(payload: #"{"sub":"anon-1","is_anonymous":true}"#),
            refreshToken: "refresh",
            userId: "anon-1",
            email: nil
        )

        let repaired = AuthService.repairingAnonymousFlag(saved)

        XCTAssertEqual(repaired.isAnonymous, true)
        XCTAssertFalse(repaired.isAccountSession, "A guest saved without the flag must restore as a guest")
        XCTAssertEqual(repaired.accessToken, saved.accessToken)
        XCTAssertEqual(repaired.refreshToken, saved.refreshToken)
        XCTAssertEqual(repaired.userId, saved.userId)
    }

    func testRestoredSessionWithFalseClaimStaysAccount() {
        let saved = AuthSession(
            accessToken: Self.makeJWT(payload: #"{"sub":"user-1","is_anonymous":false}"#),
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@b.com"
        )

        XCTAssertEqual(JWTDecoder.isAnonymous(from: saved.accessToken), false)
        let repaired = AuthService.repairingAnonymousFlag(saved)

        XCTAssertEqual(repaired, saved)
        XCTAssertTrue(repaired.isAccountSession)
    }

    func testRestoredSessionWithoutClaimOrWithBadTokenIsUnchanged() {
        let noClaim = AuthSession(
            accessToken: Self.makeJWT(payload: #"{"sub":"user-1"}"#),
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@b.com"
        )
        let badToken = AuthSession(
            accessToken: "not-a-jwt",
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@b.com"
        )

        XCTAssertNil(JWTDecoder.isAnonymous(from: noClaim.accessToken))
        XCTAssertNil(JWTDecoder.isAnonymous(from: badToken.accessToken))
        XCTAssertEqual(AuthService.repairingAnonymousFlag(noClaim), noClaim)
        XCTAssertEqual(AuthService.repairingAnonymousFlag(badToken), badToken)
    }

    /// An explicit `false` came from the server after the refresh fix and wins
    /// over a token claim, which can be stale right after a guest upgrades.
    func testRestoredSessionWithExplicitFalseFlagIgnoresAnonymousClaim() {
        let saved = AuthSession(
            accessToken: Self.makeJWT(payload: #"{"sub":"user-1","is_anonymous":true}"#),
            refreshToken: "refresh",
            userId: "user-1",
            email: "a@b.com",
            isAnonymous: false
        )

        XCTAssertEqual(AuthService.repairingAnonymousFlag(saved), saved)
    }

    private static func makeJWT(payload: String) -> String {
        func base64URL(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = base64URL(Data(#"{"alg":"none","typ":"JWT"}"#.utf8))
        return "\(header).\(base64URL(Data(payload.utf8))).signature"
    }

    func testAuthServiceErrorDetectsInvalidGrant() {
        let error = AuthServiceError.serverError("invalid_grant: Refresh Token Not Found")
        XCTAssertTrue(error.isAuthFailure)
    }
}
