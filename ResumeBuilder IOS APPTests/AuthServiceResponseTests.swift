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

    func testAuthServiceErrorDetectsInvalidGrant() {
        let error = AuthServiceError.serverError("invalid_grant: Refresh Token Not Found")
        XCTAssertTrue(error.isAuthFailure)
    }
}
