import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// App Review 5.1.2(i): personal data may go to a third-party AI only after the
/// user is told and gives explicit permission.
///
/// Pins the PR #200 review findings: every OpenAI-backed send is gated (not only
/// Home's "Check my fit"), consent belongs to one account and is cleared on
/// sign-out, and no screen still says the résumé is never shared.
@MainActor
final class AIConsentTests: XCTestCase {

    /// A fresh, private defaults suite per test, removed when the test ends.
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "AIConsentTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return defaults
    }

    // MARK: Store, scoped per account

    func testNewIdentityNeedsConsentBeforeSending() {
        let store = AIConsentStore(identity: "user-a", defaults: makeDefaults())
        XCTAssertFalse(store.hasConsented)
        XCTAssertTrue(store.needsConsentBeforeSending)
        XCTAssertNil(store.consentedAt)
    }

    func testRecordedConsentPersistsWithItsDate() {
        let defaults = makeDefaults()
        let date = Date(timeIntervalSince1970: 1_792_400_000)
        AIConsentStore(identity: "user-a", defaults: defaults).recordConsent(at: date)

        let reread = AIConsentStore(identity: "user-a", defaults: defaults)
        XCTAssertTrue(reread.hasConsented)
        XCTAssertEqual(reread.consentedAt, date)
    }

    /// Review finding 2: a second account on the same phone must not inherit
    /// the first account's yes.
    func testSecondAccountDoesNotInheritConsent() {
        let defaults = makeDefaults()
        AIConsentStore(identity: "user-a", defaults: defaults).recordConsent()

        XCTAssertTrue(AIConsentStore(identity: "user-a", defaults: defaults).hasConsented)
        XCTAssertFalse(AIConsentStore(identity: "user-b", defaults: defaults).hasConsented)
        XCTAssertFalse(AIConsentStore(identity: AIConsentStore.guestIdentity, defaults: defaults).hasConsented)
    }

    func testIdentityIsTheUserIdOrGuest() {
        XCTAssertEqual(AIConsentStore.identity(forUserId: "abc-123"), "abc-123")
        XCTAssertEqual(AIConsentStore.identity(forUserId: nil), "guest")
        XCTAssertEqual(AIConsentStore.identity(forUserId: "  "), "guest")
    }

    /// Versioned so a change in what is sent, or to whom, can ask everyone again.
    func testConsentKeyIsVersionedAndScoped() {
        XCTAssertEqual(AIConsentStore.key(for: "abc"), "ai_data_consent_v1.abc")
    }

    func testClearAllRemovesEveryIdentityAndTheUnscopedKey() {
        let defaults = makeDefaults()
        AIConsentStore(identity: "user-a", defaults: defaults).recordConsent()
        AIConsentStore(identity: "guest", defaults: defaults).recordConsent()
        defaults.set(1.0, forKey: "ai_data_consent_v1")
        defaults.set("keep", forKey: "ai_data_consent_v10_unrelated")

        AIConsentStore.clearAll(defaults: defaults)

        XCTAssertFalse(AIConsentStore(identity: "user-a", defaults: defaults).hasConsented)
        XCTAssertFalse(AIConsentStore(identity: "guest", defaults: defaults).hasConsented)
        XCTAssertNil(defaults.object(forKey: "ai_data_consent_v1"))
        XCTAssertEqual(defaults.string(forKey: "ai_data_consent_v10_unrelated"), "keep")
    }

    /// Review finding 2: sign-out (and account deletion, which calls it) resets
    /// consent, so the next person on the phone is asked.
    func testSignOutClearsConsent() {
        let key = AIConsentStore.key(for: "signout-test-user")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        addTeardownBlock { UserDefaults.standard.removeObject(forKey: key) }

        AppState(authClient: ConsentTestAuthClient()).signOut()

        XCTAssertNil(UserDefaults.standard.object(forKey: key))
    }

    // MARK: Center

    func testCenterAsksOnceAndRemembersYesForThatAccount() async {
        let presenter = StubPresenter(answer: true)
        let center = AIConsentCenter(defaults: makeDefaults(), presenter: presenter)
        center.userIdProvider = { "user-a" }

        let first = await center.ensureConsent(source: "test")
        let second = await center.ensureConsent(source: "test")

        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(presenter.presentCount, 1)
        XCTAssertTrue(center.hasConsented)
    }

    func testCenterDeclineSendsNothingAndAsksAgainNextTime() async {
        let presenter = StubPresenter(answer: false)
        let center = AIConsentCenter(defaults: makeDefaults(), presenter: presenter)
        center.userIdProvider = { "user-a" }

        let first = await center.ensureConsent(source: "test")
        let second = await center.ensureConsent(source: "test")

        XCTAssertFalse(first)
        XCTAssertFalse(second)
        XCTAssertEqual(presenter.presentCount, 2)
        XCTAssertFalse(center.hasConsented)
    }

    /// Review finding 2, end to end: switching accounts asks again.
    func testCenterAsksAgainAfterAccountSwitch() async {
        let presenter = StubPresenter(answer: true)
        let center = AIConsentCenter(defaults: makeDefaults(), presenter: presenter)
        var userId = "user-a"
        center.userIdProvider = { userId }

        _ = await center.ensureConsent(source: "test")
        userId = "user-b"
        XCTAssertFalse(center.hasConsented)
        _ = await center.ensureConsent(source: "test")

        XCTAssertEqual(presenter.presentCount, 2)
    }

    /// Two sends at once (say chat and a rescore) share one sheet.
    func testConcurrentRequestsShareOneSheet() async {
        let presenter = StubPresenter(answer: nil)
        let center = AIConsentCenter(defaults: makeDefaults(), presenter: presenter)
        center.userIdProvider = { "user-a" }

        async let first = center.ensureConsent(source: "a")
        async let second = center.ensureConsent(source: "b")
        while presenter.pending.isEmpty { await Task.yield() }
        for _ in 0..<5 { await Task.yield() }
        presenter.answerPending(true)

        let results = await [first, second]
        XCTAssertEqual(results, [true, true])
        XCTAssertEqual(presenter.presentCount, 1)
    }

    /// CodeRabbit on b4169f5: a sign-out while the sheet is open must void a
    /// later "Agree", so the signed-out identity is not left with consent.
    func testSignOutWhileSheetIsOpenVoidsALaterYes() async {
        let defaults = makeDefaults()
        let presenter = StubPresenter(answer: nil)
        let center = AIConsentCenter(defaults: defaults, presenter: presenter)
        center.userIdProvider = { "user-a" }

        async let result = center.ensureConsent(source: "test")
        while presenter.pending.isEmpty { await Task.yield() }
        center.clearAll()
        presenter.answerPending(true)

        let agreed = await result
        XCTAssertFalse(agreed)
        XCTAssertFalse(center.hasConsented)
        XCTAssertFalse(AIConsentStore(identity: "user-a", defaults: defaults).hasConsented)
    }

    /// A yes given after an earlier sign-out (a new sheet) still counts.
    func testConsentAfterSignOutIsRecordedForTheNewAsk() async {
        let presenter = StubPresenter(answer: true)
        let center = AIConsentCenter(defaults: makeDefaults(), presenter: presenter)
        center.userIdProvider = { "user-a" }

        center.clearAll()
        let agreed = await center.ensureConsent(source: "test")

        XCTAssertTrue(agreed)
        XCTAssertTrue(center.hasConsented)
    }

    /// CodeRabbit on b4169f5: two quick taps on "Check my fit" must start one
    /// check, not two.
    func testCheckStartLatchLetsOneStartThrough() {
        var latch = CheckStartLatch()
        XCTAssertTrue(latch.begin())
        XCTAssertFalse(latch.begin(), "a second tap while the first is starting must be ignored")
        XCTAssertTrue(latch.isStarting)
        latch.end()
        XCTAssertFalse(latch.isStarting)
        XCTAssertTrue(latch.begin(), "after the first start resolves, the next tap starts again")
    }

    // MARK: Every OpenAI-backed send is gated (review finding 1)

    func testEveryOpenAIBackedPostIsGated() {
        let gated: [Endpoint] = [
            .publicATSCheck, .atsScore, .atsRescan, .optimize, .uploadResume,
            .refineSection, .chatSend, .chatApproveChange,
            .expertWorkflowRunPost, .expertWorkflowApply(runId: "r"),
            .applicationExpertReports(id: "a"), .optimizationReviewApply(id: "o"),
            .keywordSuggestionPreview(optimizationId: "o", suggestionId: "s"),
        ]
        for endpoint in gated {
            XCTAssertTrue(endpoint.sendsPersonalDataToAI, "\(endpoint.path) must ask for consent")
        }

        let notGated: [Endpoint] = [
            .credits, .applications, .optimizations, .savedResumes,
            .convertAnonymousSession, .designRenderPreview, .download(id: "d"),
        ]
        for endpoint in notGated {
            XCTAssertFalse(endpoint.sendsPersonalDataToAI, "\(endpoint.path) sends nothing to AI")
        }
    }

    /// Chat on a restored optimization (the path the review found ungated) is
    /// refused before any request leaves the phone.
    func testDeclinedConsentBlocksChatBeforeAnyRequest() async {
        let api = makeClient(gate: .denyAll)
        ConsentMockURLProtocol.requestCount = 0
        ConsentMockURLProtocol.handler = { _ in (Self.okResponse(), Data("{}".utf8)) }
        defer { ConsentMockURLProtocol.handler = nil }

        do {
            let _: APIStatusResponse = try await api.postJSONObject(
                endpoint: .chatSend, bodyObject: ["message": "hi"], token: "t"
            )
            XCTFail("chat must not send without consent")
        } catch {
            XCTAssertEqual(error as? AIConsentError, .declined)
        }
        XCTAssertEqual(ConsentMockURLProtocol.requestCount, 0)
    }

    /// Refine on a restored optimization, the other ungated path in the review.
    func testDeclinedConsentBlocksRefineBeforeAnyRequest() async {
        let api = makeClient(gate: .denyAll)
        ConsentMockURLProtocol.requestCount = 0
        ConsentMockURLProtocol.handler = { _ in (Self.okResponse(), Data("{}".utf8)) }
        defer { ConsentMockURLProtocol.handler = nil }

        do {
            let _: APIStatusResponse = try await api.postJSON(
                endpoint: .refineSection, body: ["section": "summary"], token: "t"
            )
            XCTFail("refine must not send without consent")
        } catch {
            XCTAssertEqual(error as? AIConsentError, .declined)
        }
        XCTAssertEqual(ConsentMockURLProtocol.requestCount, 0)
    }

    func testDeclinedConsentDoesNotBlockNonAIPosts() async throws {
        let api = makeClient(gate: .denyAll)
        ConsentMockURLProtocol.requestCount = 0
        ConsentMockURLProtocol.handler = { _ in (Self.okResponse(), Data(#"{"success":true}"#.utf8)) }
        defer { ConsentMockURLProtocol.handler = nil }

        let _: APIStatusResponse = try await api.postJSON(
            endpoint: .convertAnonymousSession, body: ["sessionId": "s"], token: "t"
        )
        XCTAssertEqual(ConsentMockURLProtocol.requestCount, 1)
    }

    func testGrantedConsentLetsChatSend() async throws {
        let api = makeClient(gate: .allowAll)
        ConsentMockURLProtocol.requestCount = 0
        ConsentMockURLProtocol.handler = { _ in (Self.okResponse(), Data(#"{"success":true}"#.utf8)) }
        defer { ConsentMockURLProtocol.handler = nil }

        let _: APIStatusResponse = try await api.postJSONObject(
            endpoint: .chatSend, bodyObject: ["message": "hi"], token: "t"
        )
        XCTAssertEqual(ConsentMockURLProtocol.requestCount, 1)
    }

    private func makeClient(gate: AIConsentGate) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentMockURLProtocol.self]
        return APIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: config),
            longRunningSession: URLSession(configuration: config),
            consentGate: gate
        )
    }

    nonisolated private static func okResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    // MARK: Copy

    private func extractKey(_ key: LocalizedStringKey) -> String {
        for child in Mirror(reflecting: key).children where child.label == "key" {
            if let value = child.value as? String { return value }
        }
        XCTFail("Could not extract key from LocalizedStringKey")
        return ""
    }

    private func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) }
    }

    private var sheetCopy: [(name: String, key: String)] {
        [
            ("title", extractKey(AIConsentCopy.title)),
            ("body", extractKey(AIConsentCopy.body)),
            ("agree", extractKey(AIConsentCopy.agree)),
            ("notNow", extractKey(AIConsentCopy.notNow)),
            ("privacyPolicy", extractKey(AIConsentCopy.privacyPolicy))
        ]
    }

    /// The Profile and save-account lines that replaced "never share" (review
    /// finding 3), and the message shown when a send is declined.
    private let disclosureCopy = [
        "How we use your résumé",
        "We send your résumé and job text to OpenAI to write your results. We don't sell your data. Delete it anytime.",
        "We send your résumé to OpenAI to write your results. We don't sell your data.",
        "Nothing was sent. To check your résumé, Resumely needs your OK to send it to OpenAI.",
    ]

    func testSheetCopyKeysAreTheEnglishSourceText() {
        XCTAssertEqual(extractKey(AIConsentCopy.title), "Before we read your résumé")
        XCTAssertEqual(
            extractKey(AIConsentCopy.body),
            "To check and improve your résumé, Resumely sends your résumé text and the job description to OpenAI, our AI provider. OpenAI processes them to write your results. If you check without an account, we keep the résumé and job text for up to 7 days."
        )
        XCTAssertEqual(extractKey(AIConsentCopy.agree), "Agree and continue")
        XCTAssertEqual(extractKey(AIConsentCopy.notNow), "Not now")
        XCTAssertEqual(extractKey(AIConsentCopy.privacyPolicy), "Privacy Policy")
    }

    func testDeclinedErrorUsesTheCatalogedMessage() {
        XCTAssertEqual(AIConsentError.declined.errorDescription, disclosureCopy[3])
    }

    func testHebrewTranslatesEveryConsentAndDisclosureString() throws {
        let hebrew = try hebrewBundle()
        for (name, key) in sheetCopy + disclosureCopy.map({ ("disclosure", $0) }) {
            let translated = hebrew.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(translated, key, "Hebrew falls back to English for \(name): \(key)")
            XCTAssertTrue(containsHebrew(translated), "No Hebrew in \(name): \(translated)")
            XCTAssertFalse(translated.contains("\u{2014}"), "Em dash in Hebrew \(name)")
            XCTAssertFalse(key.contains("\u{2014}"), "Em dash in English \(name)")
        }
    }

    func testEveryDisclosureNamesOpenAIInBothLanguages() throws {
        let hebrew = try hebrewBundle()
        for key in [extractKey(AIConsentCopy.body)] + disclosureCopy.dropFirst() {
            XCTAssertTrue(key.contains("OpenAI"), key)
            XCTAssertTrue(hebrew.localizedString(forKey: key, value: nil, table: nil).contains("OpenAI"), key)
        }
    }

    /// Review finding 3: no screen may still say the résumé is never shared or
    /// stays private, in either language.
    func testCatalogCarriesNoNeverSharedClaim() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "he")
        )
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        let banned = [
            "never shared", "never share", "never sell", "stays private", "end-to-end",
            "לעולם לא משותפים", "מקצה לקצה", "לא מוכרים או משתפים", "נשארים פרטיים",
        ]
        for (key, value) in table {
            for fragment in banned {
                XCTAssertFalse(key.contains(fragment), "Catalog key still claims \"\(fragment)\": \(key)")
                XCTAssertFalse(value.contains(fragment), "Hebrew value still claims \"\(fragment)\": \(value)")
            }
        }
    }

    private func hebrewBundle() throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}

// MARK: - Test doubles

@MainActor
private final class StubPresenter: AIConsentPresenting {
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

private final class ConsentTestAuthClient: AuthClient, @unchecked Sendable {
    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func refreshSession(refreshToken: String) async throws -> AuthSession { throw URLError(.notConnectedToInternet) }
    func deleteAccount(accessToken: String) async throws {}
}

private final class ConsentMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
