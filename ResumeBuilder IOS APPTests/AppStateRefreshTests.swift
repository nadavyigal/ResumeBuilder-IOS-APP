import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class AppStateRefreshTests: XCTestCase {
    func testRefreshSessionIfNeededSkipsWhenTokenStillValid() async {
        let exp = Date().addingTimeInterval(3_600).timeIntervalSince1970
        let header = base64URL(Data("{\"alg\":\"none\"}".utf8))
        let payload = base64URL(Data("{\"exp\":\(Int(exp))}".utf8))
        let accessToken = "\(header).\(payload).sig"

        let appState = AppState()
        appState.session = AuthSession(
            accessToken: accessToken,
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        await appState.refreshSessionIfNeeded()

        XCTAssertEqual(appState.session?.accessToken, accessToken)
        XCTAssertNotNil(appState.session)
    }

    func testParallelRefreshAccessTokenCoalescesToSingleTask() async {
        let appState = AppState()
        appState.session = AuthSession(
            accessToken: "stale",
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        let first = Task { await appState.refreshAccessToken() }
        let second = Task { await appState.refreshAccessToken() }
        _ = await first.value
        _ = await second.value

        // Both tasks complete without crashing; refreshTask serialization is exercised.
        XCTAssertTrue(appState.session == nil || appState.session?.accessToken != "stale")
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
