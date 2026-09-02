import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class AppStateRefreshTests: XCTestCase {
    func testRefreshSessionIfNeededSkipsWhenTokenStillValid() async {
        let exp = Date().addingTimeInterval(3_600).timeIntervalSince1970
        let header = base64URL(Data("{\"alg\":\"none\"}".utf8))
        let payload = base64URL(Data("{\"exp\":\(Int(exp))}".utf8))
        let accessToken = "\(header).\(payload).sig"

        let stub = StubAuthClient(result: .failure(URLError(.notConnectedToInternet)))
        let appState = AppState(authClient: stub)
        appState.session = AuthSession(
            accessToken: accessToken,
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        await appState.refreshSessionIfNeeded()

        XCTAssertEqual(appState.session?.accessToken, accessToken)
        XCTAssertEqual(stub.refreshCallCount, 0, "A token that is still valid must not be refreshed.")
    }

    /// Two concurrent callers must share one in-flight refresh — the point of `refreshTask`.
    func testParallelRefreshAccessTokenIssuesOneRefreshCall() async {
        let stub = StubAuthClient(
            result: .success(
                AuthSession(
                    accessToken: "fresh",
                    refreshToken: "refresh-token-2",
                    userId: "user-1",
                    email: nil
                )
            ),
            holdUntilReleased: true
        )
        let appState = AppState(authClient: stub)
        appState.session = AuthSession(
            accessToken: "stale",
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        let first = Task { @MainActor in await appState.refreshAccessToken() }
        let second = Task { @MainActor in await appState.refreshAccessToken() }

        // The stub holds the first refresh open, so the second caller cannot arrive
        // after the first has already finished and cleared `refreshTask`.
        await stub.waitUntilRefreshStarted()
        for _ in 0..<10 { await Task.yield() }
        stub.release()

        let firstToken = await first.value
        let secondToken = await second.value

        XCTAssertEqual(stub.refreshCallCount, 1, "Parallel refreshes must coalesce into one network call.")
        XCTAssertEqual(firstToken, "fresh")
        XCTAssertEqual(secondToken, "fresh")
        XCTAssertEqual(appState.session?.accessToken, "fresh")
    }

    /// A transport failure says nothing about the credential, so it must not sign the user out.
    func testTransportFailureDuringRefreshKeepsSession() async {
        let stub = StubAuthClient(result: .failure(URLError(.notConnectedToInternet)))
        let appState = AppState(authClient: stub)
        appState.session = AuthSession(
            accessToken: "stale",
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        let token = await appState.refreshAccessToken()

        XCTAssertNil(token)
        XCTAssertEqual(stub.refreshCallCount, 1)
        XCTAssertEqual(appState.session?.accessToken, "stale", "Offline must not clear the session.")
    }

    /// A rejected refresh token is the case that does warrant a sign-out.
    func testRejectedRefreshTokenSignsOut() async {
        let stub = StubAuthClient(
            result: .failure(AuthServiceError.serverError("invalid_grant: Refresh Token Not Found"))
        )
        let appState = AppState(authClient: stub)
        appState.session = AuthSession(
            accessToken: "stale",
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )

        let token = await appState.refreshAccessToken()

        XCTAssertNil(token)
        XCTAssertEqual(stub.refreshCallCount, 1)
        XCTAssertNil(appState.session, "A rejected refresh token must clear the session.")
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Counts `refreshSession` calls and can hold one open, so refresh coalescing and the
/// sign-out policy can be observed without touching the network.
private final class StubAuthClient: AuthClient, @unchecked Sendable {
    private let result: Result<AuthSession, Error>
    private let holdUntilReleased: Bool

    private let lock = NSLock()
    private var callCount = 0
    private var didEnterRefresh = false
    private var isReleased = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(result: Result<AuthSession, Error>, holdUntilReleased: Bool = false) {
        self.result = result
        self.holdUntilReleased = holdUntilReleased
    }

    var refreshCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCount
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        recordRefreshEntry()
        if holdUntilReleased {
            await waitForRelease()
        }
        return try result.get()
    }

    // NSLock cannot be taken directly in an async context, so the critical section
    // lives in this synchronous helper.
    private func recordRefreshEntry() {
        lock.lock()
        callCount += 1
        didEnterRefresh = true
        let waiters = entryWaiters
        entryWaiters = []
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    /// Suspends until `refreshSession` has been entered at least once.
    func waitUntilRefreshStarted() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if didEnterRefresh {
                lock.unlock()
                continuation.resume()
            } else {
                entryWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    /// Lets every held `refreshSession` call return.
    func release() {
        lock.lock()
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters = []
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    private func waitForRelease() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isReleased {
                lock.unlock()
                continuation.resume()
            } else {
                releaseWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func restoreSession() -> AuthSession? { nil }

    func clearSession() {}

    func deleteAccount(accessToken: String) async throws {}
}
