import XCTest
@testable import ResumeBuilder_IOS_APP

/// Issue #204, founder device test on 1.5.4 (33), 2026-10-21: a new guest tapped
/// Check before the anonymous Supabase session existed, so the yes was stored
/// under `guest`. On the next launch the anonymous session started, the identity
/// became the anonymous user id, and the same person was asked again.
///
/// These pin the fix: the anonymous session on this device takes over the guest's
/// yes; a real account still asks (5.1.2(i), #200); sign-out still forgets every
/// answer. They run through `AppState`, with a private center and defaults so the
/// host app's own launch (which may start a real anonymous session) cannot reach them.
@MainActor
final class GuestConsentCarryOverTests: XCTestCase {
    private var defaults: UserDefaults!
    private var center: AIConsentCenter!

    override func setUp() async throws {
        try await super.setUp()
        let suite = "GuestConsentCarryOverTests.\(name)"
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
    }

    /// A guest with no session yet, a stubbed anonymous sign-in, and a center
    /// reading this `AppState`'s user id (as the app root wires the shared one).
    private func makeGuest(
        answer: Bool?,
        anonymousSession: AuthSession? = nil
    ) -> (AppState, CarryOverPresenter) {
        let anonymous = anonymousSession
            ?? AuthSession(accessToken: "token-anon-1", refreshToken: nil, userId: "anon-1", email: nil, isAnonymous: true)
        let presenter = CarryOverPresenter(answer: answer)
        let center = AIConsentCenter(defaults: defaults, presenter: presenter)
        let appState = AppState(authClient: CarryOverAuthClient(anonymousSession: anonymous), consentCenter: center)
        center.userIdProvider = { [weak appState] in appState?.session?.userId }
        self.center = center
        return (appState, presenter)
    }

    private func store(_ identity: String) -> AIConsentStore {
        AIConsentStore(identity: identity, defaults: defaults)
    }

    private func account(_ userId: String) -> AuthSession {
        AuthSession(accessToken: "token-\(userId)", refreshToken: nil, userId: userId, email: "\(userId)@example.com")
    }

    // MARK: The reported bug

    /// Agree as a guest, then the anonymous session starts: no second sheet.
    func testGuestWhoAgreedIsNotAskedAgainAfterTheAnonymousSessionStarts() async {
        let (appState, presenter) = makeGuest(answer: true)

        let first = await center.ensureConsent(source: "test")
        await appState.establishAnonymousSessionIfNeeded()
        XCTAssertEqual(appState.session?.userId, "anon-1")
        let second = await center.ensureConsent(source: "test")

        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(presenter.presentCount, 1, "the guest's yes belongs to their anonymous session")
    }

    /// The device-test order: agree as a guest, relaunch, the anonymous session
    /// starts on the new launch. The yes is stored, so a fresh center reads it.
    func testTheCarriedYesSurvivesARelaunch() async {
        let (appState, _) = makeGuest(answer: true)
        _ = await center.ensureConsent(source: "test")
        await appState.establishAnonymousSessionIfNeeded()

        let relaunched = AIConsentCenter(defaults: defaults, presenter: CarryOverPresenter(answer: false))
        relaunched.userIdProvider = { "anon-1" }

        XCTAssertTrue(relaunched.hasConsented)
        XCTAssertFalse(store(AIConsentStore.guestIdentity).hasConsented,
                       "the yes moves to the anonymous identity; it is not left under guest")
    }

    /// The sheet was already open as a guest when the anonymous session landed.
    /// The yes given after that still belongs to the anonymous identity.
    func testAYesGivenAfterTheAnonymousSessionLandsMidSheetIsCarried() async {
        let (appState, presenter) = makeGuest(answer: nil)

        let first = ResultBox<Bool>()
        Task { first.value = await center.ensureConsent(source: "test") }
        guard await waitUntil("the consent sheet is presented", { !presenter.pending.isEmpty }) else { return }
        await appState.establishAnonymousSessionIfNeeded()
        presenter.answerPending(true)
        guard await waitUntil("the caller gets an answer", { first.value != nil }) else { return }

        XCTAssertEqual(first.value, true)
        XCTAssertTrue(center.hasConsented)
        XCTAssertEqual(presenter.presentCount, 1)
    }

    // MARK: Never into a real account

    /// Agree as a guest, then sign in to a real account: that account is asked.
    func testRealSignInAfterGuestConsentStillAsks() async {
        let (appState, presenter) = makeGuest(answer: true)

        _ = await center.ensureConsent(source: "test")
        appState.session = account("user-2")
        XCTAssertFalse(center.hasConsented)
        _ = await center.ensureConsent(source: "test")

        XCTAssertEqual(presenter.presentCount, 2)
    }

    /// Agree as a guest, the anonymous session takes it over, then sign in to a
    /// different, real account: that account is still asked.
    func testRealSignInAfterTheCarryOverStillAsks() async {
        let (appState, presenter) = makeGuest(answer: true)

        _ = await center.ensureConsent(source: "test")
        await appState.establishAnonymousSessionIfNeeded()
        appState.session = account("user-2")
        XCTAssertFalse(center.hasConsented)
        _ = await center.ensureConsent(source: "test")

        XCTAssertEqual(presenter.presentCount, 2)
    }

    /// The carry-over is for anonymous sessions only. If the sign-in path ever
    /// hands back an account, the guest's yes stays where it was.
    func testAnAccountSessionFromTheAnonymousPathDoesNotTakeTheGuestYes() async {
        let (appState, _) = makeGuest(answer: true, anonymousSession: account("user-3"))

        _ = await center.ensureConsent(source: "test")
        await appState.establishAnonymousSessionIfNeeded()

        XCTAssertEqual(appState.session?.userId, "user-3")
        XCTAssertFalse(center.hasConsented)
    }

    // MARK: Sign-out still forgets

    /// After the carry-over, sign-out clears the answer: the next guest is asked.
    func testSignOutAfterTheCarryOverClearsConsent() async {
        let (appState, presenter) = makeGuest(answer: true)

        _ = await center.ensureConsent(source: "test")
        await appState.establishAnonymousSessionIfNeeded()
        appState.signOut()

        XCTAssertFalse(store("anon-1").hasConsented)
        XCTAssertFalse(store(AIConsentStore.guestIdentity).hasConsented)
        _ = await center.ensureConsent(source: "test")
        XCTAssertEqual(presenter.presentCount, 2)
    }

    /// Sign-out also forgets which anonymous session followed the guest: a guest
    /// yes given later must not be moved to the signed-out anonymous user.
    func testSignOutForgetsTheAnonymousSuccessor() async {
        let (appState, _) = makeGuest(answer: true)

        await appState.establishAnonymousSessionIfNeeded()
        appState.signOut()
        _ = await center.ensureConsent(source: "test")

        XCTAssertTrue(store(AIConsentStore.guestIdentity).hasConsented)
        XCTAssertFalse(store("anon-1").hasConsented)
    }

    // MARK: Store

    func testCarryMovesTheGuestYesWithItsDate() {
        let suite = "GuestConsentCarryOverTests.store"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 1_792_400_000)
        AIConsentStore(identity: AIConsentStore.guestIdentity, defaults: defaults).recordConsent(at: date)

        AIConsentStore.carryGuestConsent(to: "anon-1", defaults: defaults)

        XCTAssertEqual(AIConsentStore(identity: "anon-1", defaults: defaults).consentedAt, date)
        XCTAssertFalse(AIConsentStore(identity: AIConsentStore.guestIdentity, defaults: defaults).hasConsented)
    }

    func testCarryWithNoGuestYesChangesNothing() {
        let suite = "GuestConsentCarryOverTests.empty"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        AIConsentStore.carryGuestConsent(to: "anon-1", defaults: defaults)

        XCTAssertFalse(AIConsentStore(identity: "anon-1", defaults: defaults).hasConsented)
    }

    /// Polls `condition` until it holds or `timeout` passes, then fails the test
    /// instead of hanging the run.
    private func waitUntil(
        _ what: String,
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            if ContinuousClock.now >= deadline {
                XCTFail("Timed out waiting until \(what)")
                return false
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return true
    }
}

private final class ResultBox<Value> {
    var value: Value?
}

@MainActor
private final class CarryOverPresenter: AIConsentPresenting {
    /// nil holds the sheet open until `answerPending` is called.
    let answer: Bool?
    private(set) var presentCount = 0
    private(set) var pending: [@MainActor (Bool) -> Void] = []

    init(answer: Bool?) { self.answer = answer }

    func present(completion: @escaping @MainActor (Bool) -> Void) {
        presentCount += 1
        if let answer {
            completion(answer)
        } else {
            pending.append(completion)
        }
    }

    func answerPending(_ agreed: Bool) {
        let completions = pending
        pending = []
        completions.forEach { $0(agreed) }
    }
}

private final class CarryOverAuthClient: AuthClient, @unchecked Sendable {
    let anonymousSession: AuthSession

    init(anonymousSession: AuthSession) { self.anonymousSession = anonymousSession }

    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func refreshSession(refreshToken: String) async throws -> AuthSession { throw URLError(.notConnectedToInternet) }
    func deleteAccount(accessToken: String) async throws {}
    func signInAnonymously() async throws -> AuthSession { anonymousSession }
}
