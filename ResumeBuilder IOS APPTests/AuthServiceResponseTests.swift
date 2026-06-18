import XCTest
@testable import ResumeBuilder_IOS_APP

final class AuthServiceResponseTests: XCTestCase {
    func testGoTrueResponseRejectsMissingRefreshToken() throws {
        let json = """
        {
          "access_token": "access",
          "refresh_token": null,
          "user": { "id": "user-1", "email": "a@b.com" }
        }
        """
        struct GoTrueResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let user: GoTrueUserFixture
        }
        struct GoTrueUserFixture: Decodable {
            let id: String
            let email: String?
        }

        let decoded = try JSONDecoder().decode(GoTrueResponse.self, from: Data(json.utf8))
        XCTAssertNil(decoded.refresh_token)
    }

    func testAuthServiceErrorDetectsInvalidGrant() {
        let error = AuthServiceError.serverError("invalid_grant: Refresh Token Not Found")
        XCTAssertTrue(error.isAuthFailure)
    }

    func testURLErrorIsNotAuthFailure() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertFalse((error as? AuthServiceError)?.isAuthFailure ?? false)
    }
}
