import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S2: Pro is recorded by the server, the app only shows it, and Pro
// bought under another Resumely account is never finished for this one.

private final class PlanRequestBox: @unchecked Sendable {
    var paths: [String] = []
}

/// Serves one canned answer per test through a real `APIClient` and `URLSession`.
private final class PlanMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var json = "{}"
    nonisolated(unsafe) static var box = PlanRequestBox()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.box.paths.append(request.url?.path ?? "")
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
private func planClient(status: Int, json: String, box: PlanRequestBox = PlanRequestBox()) -> APIClient {
    PlanMockURLProtocol.status = status
    PlanMockURLProtocol.json = json
    PlanMockURLProtocol.box = box
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PlanMockURLProtocol.self]
    return APIClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: config))
}

private struct ThrowingVerifier: PurchaseVerifying {
    let error: ReceiptVerifierError
    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        throw error
    }
}

@MainActor
final class SubscriptionEntitlementTests: XCTestCase {
    private let account = PurchaseAccount(userId: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, token: "tok")

    func testTheVerifyAnswerForProCarriesThePlan() async throws {
        let verifier = ReceiptVerifier(apiClient: planClient(
            status: 200,
            json: #"{"success":true,"status":"granted","creditsGranted":0,"balance":null,"entitlement":{"active":true,"productId":"resumely.pro.monthly","expiresAt":"2026-11-29T10:00:00.000Z"}}"#
        ))

        let result = try await verifier.verify(signedTransaction: "jws", productId: ResumelyProducts.proMonthly, token: "tok")

        XCTAssertEqual(result.creditsGranted, 0)
        XCTAssertNil(result.balance)
        let entitlement = try XCTUnwrap(result.entitlement)
        XCTAssertTrue(entitlement.active)
        XCTAssertEqual(entitlement.productId, "resumely.pro.monthly")
        XCTAssertEqual(entitlement.expiryDate, ISO8601DateFormatter().date(from: "2026-11-29T10:00:00Z"))
    }

    func testAPackAnswerHasNoPlan() async throws {
        let verifier = ReceiptVerifier(apiClient: planClient(
            status: 200,
            json: #"{"success":true,"status":"granted","creditsGranted":14,"balance":17}"#
        ))
        let result = try await verifier.verify(signedTransaction: "jws", productId: ResumelyProducts.exports14, token: "tok")
        XCTAssertEqual(result, PurchaseVerification(status: "granted", creditsGranted: 14, balance: 17))
    }

    func testProOwnedByAnotherAccountIsNamed() async {
        let verifier = ReceiptVerifier(apiClient: planClient(status: 409, json: #"{"error":"subscription_owned_by_another_account"}"#))
        do {
            _ = try await verifier.verify(signedTransaction: "j", productId: ResumelyProducts.proMonthly, token: "t")
            XCTFail("expected ownedByAnotherAccount")
        } catch {
            XCTAssertEqual(error as? ReceiptVerifierError, .ownedByAnotherAccount)
        }
    }

    func testProWithAnotherAccountsTokenIsNamedButAPackStaysRetriable() async {
        let pro = ReceiptVerifier(apiClient: planClient(status: 403, json: #"{"error":"account_mismatch"}"#))
        do {
            _ = try await pro.verify(signedTransaction: "j", productId: ResumelyProducts.proMonthly, token: "t")
            XCTFail("expected ownedByAnotherAccount")
        } catch {
            XCTAssertEqual(error as? ReceiptVerifierError, .ownedByAnotherAccount)
        }

        let pack = ReceiptVerifier(apiClient: planClient(status: 403, json: #"{"error":"account_mismatch"}"#))
        do {
            _ = try await pack.verify(signedTransaction: "j", productId: ResumelyProducts.exports5, token: "t")
            XCTFail("expected notGranted")
        } catch {
            XCTAssertEqual(error as? ReceiptVerifierError, .notGranted(status: 403, code: "account_mismatch"))
        }
    }

    func testProOfAnotherAccountIsLeftUnfinishedForThatAccount() async {
        var finished = false
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: ResumelyProducts.proMonthly,
            account: account,
            verifier: ThrowingVerifier(error: .ownedByAnotherAccount),
            finish: { finished = true }
        )
        XCTAssertEqual(decision, .otherAccount)
        XCTAssertFalse(finished)
    }

    func testProOfAnotherAccountNeverLocksThePaywall() {
        let defaults = UserDefaults(suiteName: "plan-lock-\(UUID().uuidString)")!
        let store = StoreKitManager(defaults: defaults)
        store.recordDelivery(.otherAccount, buyer: account.userId, productID: ResumelyProducts.proMonthly)
        XCTAssertNil(store.pendingProductID(for: account.userId))
    }

    func testAFailedProDeliveryNeverLocksPackSales() {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "plan-keep-\(UUID().uuidString)")!)
        store.recordDelivery(.keep(reason: "network"), buyer: account.userId, productID: ResumelyProducts.proMonthly)
        XCTAssertNil(store.pendingProductID(for: account.userId))
    }

    /// Covers a Pro purchase that is charged but not granted, and Ask to Buy
    /// for Pro: neither may leave a lock with nothing to clear it.
    func testProNeverSetsALockButAPackStillDoes() {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "plan-set-\(UUID().uuidString)")!)
        store.setPendingLock(userId: account.userId, productID: ResumelyProducts.proMonthly)
        XCTAssertNil(store.pendingProductID(for: account.userId))

        store.setPendingLock(userId: account.userId, productID: ResumelyProducts.exports5)
        XCTAssertEqual(store.pendingProductID(for: account.userId), ResumelyProducts.exports5)
    }

    func testOnlyARetryablePackFailureLocks() {
        for reason in ["network", "no_account", "401_token_expired", "429_rate_limited", "500_failed_to_grant_credits", "503_iap_verification_unavailable"] {
            let store = StoreKitManager(defaults: UserDefaults(suiteName: "pack-keep-\(UUID().uuidString)")!)
            store.recordDelivery(.keep(reason: reason), buyer: account.userId, productID: ResumelyProducts.exports14)
            XCTAssertEqual(store.pendingProductID(for: account.userId), ResumelyProducts.exports14, reason)
        }
        for reason in ["400_invalid_signature", "400_unknown_product", "403_account_mismatch", "409_transaction_owned_by_another_account"] {
            let store = StoreKitManager(defaults: UserDefaults(suiteName: "pack-refused-\(UUID().uuidString)")!)
            store.recordDelivery(.keep(reason: reason), buyer: account.userId, productID: ResumelyProducts.exports14)
            XCTAssertNil(store.pendingProductID(for: account.userId), reason)
        }
    }

    func testOnlyAnActivePlanResumesAWaitingPaywall() async {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "plan-grant-\(UUID().uuidString)")!)
        let account = account
        store.accountProvider = { _ in account }
        func plan(active: Bool) -> PurchaseVerification {
            PurchaseVerification(
                status: "already_granted",
                creditsGranted: 0,
                balance: nil,
                entitlement: SubscriptionEntitlement(active: active, productId: ResumelyProducts.proMonthly, expiresAt: nil)
            )
        }

        await store.publishBackgroundGrant(plan(active: false), for: account.userId)
        XCTAssertEqual(store.backgroundGrantCount, 0)

        await store.publishBackgroundGrant(plan(active: true), for: account.userId)
        XCTAssertEqual(store.backgroundGrantCount, 1)

        await store.publishBackgroundGrant(PurchaseVerification(status: "granted", creditsGranted: 5, balance: 5), for: account.userId)
        XCTAssertEqual(store.backgroundGrantCount, 2)
    }

    func testTheMessageNamesTheOtherAccountWithoutAPrice() {
        let message = StoreKitManagerError.ownedByAnotherAccount.localizedDescription
        XCTAssertEqual(message, "This subscription belongs to another Resumely account. Sign in with that account.")
        XCTAssertFalse(message.contains("$"))
    }

    func testCreditsReadsThePlanAndItsFairUseCount() throws {
        let json = #"""
        {"balance":2,"transactions":[],"subscription":{"active":true,"productId":"resumely.pro.monthly","expiresAt":"2026-11-29T10:00:00+00:00","graceUntil":null,"autoRenew":false,"periodExports":12,"periodCap":40}}
        """#
        let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.balance, 2)
        XCTAssertEqual(response.subscription, SubscriptionStatus(
            active: true,
            productId: "resumely.pro.monthly",
            expiresAt: "2026-11-29T10:00:00+00:00",
            autoRenew: false,
            periodExports: 12,
            periodCap: 40
        ))
        XCTAssertEqual(response.subscription?.expiryDate, ISO8601DateFormatter().date(from: "2026-11-29T10:00:00Z"))
    }

    func testCreditsFromAServerBeforePricingV2HasNoPlan() throws {
        let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(#"{"balance":1,"transactions":[]}"#.utf8))
        XCTAssertEqual(response.balance, 1)
        XCTAssertNil(response.subscription)
    }

    func testAnExportProPaidForSaysSo() throws {
        let response = try JSONDecoder().decode(
            ExportUnlockService.Response.self,
            from: Data(#"{"status":"unlocked","balance":0,"source":"subscription"}"#.utf8)
        )
        XCTAssertEqual(response, ExportUnlockService.Response(status: "unlocked", balance: 0, source: "subscription"))

        let older = try JSONDecoder().decode(ExportUnlockService.Response.self, from: Data(#"{"status":"ungated","balance":null}"#.utf8))
        XCTAssertNil(older.source)
    }

    func testRefreshCreditsKeepsThePlanAndSignOutClearsIt() async {
        let box = PlanRequestBox()
        let appState = AppState(apiClient: planClient(
            status: 200,
            json: #"{"balance":3,"transactions":[],"subscription":{"active":true,"productId":"resumely.pro.monthly","expiresAt":"2026-11-29T10:00:00+00:00","periodExports":0,"periodCap":40}}"#,
            box: box
        ))
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: account.userId.uuidString, email: "a@example.com")

        await appState.refreshCredits()

        XCTAssertEqual(box.paths, ["/api/v1/credits"])
        XCTAssertEqual(appState.creditsBalance, 3)
        XCTAssertEqual(appState.subscription?.active, true)
        XCTAssertEqual(appState.subscription?.periodCap, 40)

        appState.signOut()
        XCTAssertNil(appState.subscription)
    }

    func testServerDatesWithAndWithoutFractionsParse() {
        XCTAssertNotNil(ServerDate.parse("2026-11-29T10:00:00+00:00"))
        XCTAssertNotNil(ServerDate.parse("2026-11-29T10:00:00.123Z"))
        XCTAssertNil(ServerDate.parse("next month"))
        XCTAssertNil(ServerDate.parse(nil))
    }
}
