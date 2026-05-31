import XCTest
@testable import ResumeBuilder_IOS_APP

final class ProfileAccountDisplayTests: XCTestCase {
    func testGuestModeLabels() {
        let info = AccountDisplayInfo.resolve(isAuthenticated: false, email: nil)
        XCTAssertEqual(info.title, "Guest mode")
        XCTAssertTrue(info.showsSignIn)
        XCTAssertFalse(info.showsSignOut)
        XCTAssertEqual(info.avatarInitials, "G")
    }

    func testAuthenticatedShowsEmailAndSignOut() {
        let info = AccountDisplayInfo.resolve(isAuthenticated: true, email: "jane.doe@example.com")
        if case .authenticated(let email, let initials) = info {
            XCTAssertEqual(email, "jane.doe@example.com")
            XCTAssertEqual(initials, "JD")
        } else {
            XCTFail("Expected authenticated state")
        }
        XCTAssertTrue(info.showsSignOut)
        XCTAssertFalse(info.showsSignIn)
    }

    func testAuthenticatedWithoutEmailUsesAccountFallback() {
        let info = AccountDisplayInfo.resolve(isAuthenticated: true, email: nil)
        if case .authenticated(let email, _) = info {
            XCTAssertEqual(email, "Account")
        } else {
            XCTFail("Expected authenticated state")
        }
    }
}
