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
        XCTAssertEqual(stub.savedSession?.accessToken, "fresh")
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

    func testPasswordRefreshCannotRestoreSignedOutSession() async {
        await assertPasswordRefreshCannotCrossSession(replacement: nil)
    }

    func testPasswordRefreshCannotReplaceAnotherAccount() async {
        await assertPasswordRefreshCannotCrossSession(replacement: makeSession("user-2", token: "B"))
    }

    func testPasswordRefreshCannotSurviveSameAccountSignIn() async {
        // Identical credentials still represent a new sign-in after sign-out.
        await assertPasswordRefreshCannotCrossSession(replacement: makeSession("user-1", token: "stale"))
    }

    func testPasswordRefreshFailureCannotSignOutReplacementAccount() async {
        await assertPasswordRefreshCannotCrossSession(
            replacement: makeSession("user-2", token: "B"),
            result: .failure(AuthServiceError.serverError("invalid_grant: Refresh Token Not Found"))
        )
    }

    func testOrdinaryPasswordRetryPersistsRefreshedSession() async throws {
        let stub = StubAuthClient(result: .success(makeSession("user-1", token: "fresh")))
        let appState = AppState(authClient: stub)
        appState.session = makeSession("user-1", token: "stale")

        try await appState.changePassword(String(repeating: "q", count: 16))

        XCTAssertEqual(stub.passwordTokens, ["stale", "fresh"])
        XCTAssertEqual(appState.session?.accessToken, "fresh")
        XCTAssertEqual(stub.savedSession?.accessToken, "fresh")
    }

    func testLaunchRefreshCannotRestoreSignedOutSession() async {
        let stub = StubAuthClient(
            result: .success(makeSession("user-1", token: "fresh")), holdUntilReleased: true
        )
        let appState = AppState(authClient: stub)
        appState.session = makeSession("user-1", token: "expired")
        let refresh = Task { await appState.refreshSessionIfNeeded() }
        await stub.waitUntilRefreshStarted()
        appState.signOut()
        stub.release()
        await refresh.value

        XCTAssertNil(appState.session)
        XCTAssertNil(stub.savedSession)
    }

    func testReplacingSessionWithoutSignOutInvalidatesRefresh() async {
        let stub = StubAuthClient(
            result: .success(makeSession("user-1", token: "fresh")), holdUntilReleased: true
        )
        let appState = AppState(authClient: stub)
        appState.session = makeSession("user-1", token: "stale")
        let refresh = Task { await appState.refreshAccessToken() }
        await stub.waitUntilRefreshStarted()
        appState.session = makeSession("user-2", token: "B")
        stub.release()
        let token = await refresh.value

        XCTAssertNil(token)
        XCTAssertEqual(appState.session?.accessToken, "B")
        XCTAssertNil(stub.savedSession)
    }

    func testOrdinaryLaunchRefreshPersistsRotatedCredentials() async {
        let stub = StubAuthClient(result: .success(makeSession("user-1", token: "fresh")))
        let appState = AppState(authClient: stub)
        appState.session = makeSession("user-1", token: "expired")

        await appState.refreshSessionIfNeeded()

        XCTAssertEqual(stub.refreshCallCount, 1)
        XCTAssertEqual(stub.savedSession?.accessToken, "fresh")
        XCTAssertEqual(appState.session?.accessToken, "fresh")
    }

    func testOldRefreshCompletionDoesNotClearNewAccountsRefreshTask() async {
        let oldClient = StubAuthClient(
            result: .success(makeSession("user-1", token: "old-fresh")), holdUntilReleased: true
        )
        let newClient = StubAuthClient(
            result: .success(makeSession("user-2", token: "new-fresh")), holdUntilReleased: true
        )
        let appState = AppState(authClient: RoutedAuthClient(old: oldClient, new: newClient))
        appState.session = makeSession("user-1", token: "stale")
        let oldRefresh = Task { await appState.refreshAccessToken() }
        await oldClient.waitUntilRefreshStarted()
        appState.session = makeSession("user-2", token: "B")
        let newRefresh = Task { await appState.refreshAccessToken() }
        await newClient.waitUntilRefreshStarted()

        oldClient.release()
        let oldToken = await oldRefresh.value
        XCTAssertNil(oldToken)
        var joinedRefreshEntered = false
        let joinedRefresh = Task { @MainActor in
            joinedRefreshEntered = true
            return await appState.refreshAccessToken()
        }
        // Both run on MainActor: the join enters the shared-task wait before
        // this actor can observe the flag and release the pending response.
        while !joinedRefreshEntered { await Task.yield() }
        newClient.release()
        let newToken = await newRefresh.value
        let joinedToken = await joinedRefresh.value

        XCTAssertEqual(newToken, "new-fresh")
        XCTAssertEqual(joinedToken, "new-fresh")
        XCTAssertEqual(newClient.refreshCallCount, 1, "The new account's callers must still coalesce.")
        XCTAssertEqual(appState.session?.accessToken, "new-fresh")
    }

    private func assertPasswordRefreshCannotCrossSession(
        replacement: AuthSession?, result: Result<AuthSession, Error>? = nil
    ) async {
        let stub = StubAuthClient(
            result: result ?? .success(makeSession("user-1", token: "fresh")),
            holdUntilReleased: true
        )
        let appState = AppState(authClient: stub)
        appState.session = makeSession("user-1", token: "stale")
        let change = Task { () -> Bool in
            do {
                try await appState.changePassword(String(repeating: "q", count: 16))
                return true
            } catch { return false }
        }
        await stub.waitUntilRefreshStarted()
        appState.signOut()
        appState.session = replacement
        // The stub deliberately ignores cancellation, like a request whose
        // response has already arrived. Generation checks must still reject it.
        stub.release()
        let didChangePassword = await change.value

        XCTAssertFalse(didChangePassword)
        XCTAssertEqual(appState.session, replacement)
        XCTAssertEqual(stub.passwordTokens, ["stale"])
        XCTAssertNil(stub.savedSession, "A rejected refresh must never be persisted.")
    }

    private func makeSession(_ userId: String, token: String) -> AuthSession {
        AuthSession(accessToken: token, refreshToken: "refresh-" + userId, userId: userId, email: nil)
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
    private var recordedPasswordTokens: [String] = []
    private var persistedSession: AuthSession?

    var passwordTokens: [String] { lock.withLock { recordedPasswordTokens } }
    var savedSession: AuthSession? { lock.withLock { persistedSession } }

    func persistRefreshedSession(_ session: AuthSession) {
        lock.withLock { persistedSession = session }
    }

    func updatePassword(accessToken: String, newPassword: String) async throws {
        let first = lock.withLock {
            recordedPasswordTokens.append(accessToken)
            return recordedPasswordTokens.count == 1
        }
        if first { throw APIClientError.unauthorized }
    }

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

    func clearSession() { lock.withLock { persistedSession = nil } }

    func deleteAccount(accessToken: String) async throws {}
}

/// Independent held responses let the old request finish while the new one is pending.
private struct RoutedAuthClient: AuthClient {
    let old: StubAuthClient
    let new: StubAuthClient

    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func deleteAccount(accessToken: String) async throws {}
    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let client = refreshToken == "refresh-user-1" ? old : new
        return try await client.refreshSession(refreshToken: refreshToken)
    }
}
