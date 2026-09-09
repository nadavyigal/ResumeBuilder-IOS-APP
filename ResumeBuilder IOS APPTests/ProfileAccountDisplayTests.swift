import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
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

    // WP-75 S4. Guest export is not account-gated: `ResumeExportAction.exportPDF`
    // guards only on `optimizationIdentifier`, `BackendConfig.isMonetizationEnabled`
    // is false, and Home routes anonymous sessions straight through on
    // `canOptimize`. Me-tab copy that conditions export on signing in is
    // therefore false for the exact users who are shown it.
    func testGuestCopyDoesNotGateExportBehindSignIn() {
        let info = AccountDisplayInfo.resolve(isAuthenticated: false, email: nil)
        for copy in [info.subtitle, AccountDisplayInfo.guestValueProposition] {
            let lowered = copy.lowercased()
            XCTAssertFalse(
                lowered.contains("export"),
                "Guest copy must not condition export on signing in: \(copy)"
            )
        }
    }

    func testGuestValuePropositionKeepsTheBenefitsThatAreReal() {
        let lowered = AccountDisplayInfo.guestValueProposition.lowercased()
        XCTAssertTrue(lowered.contains("save"), "History is genuinely account-gated")
        XCTAssertTrue(lowered.contains("sync"), "Sync is genuinely account-gated")
    }
}
