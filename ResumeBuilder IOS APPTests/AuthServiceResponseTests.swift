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

    func testAuthServiceErrorDetectsInvalidGrant() {
        let error = AuthServiceError.serverError("invalid_grant: Refresh Token Not Found")
        XCTAssertTrue(error.isAuthFailure)
    }
}
