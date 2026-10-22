import XCTest
@testable import ResumeBuilder_IOS_APP

// StoreKit spec 7.1, 6.4 and 10: the server decides every export, a transaction
// is finished only after the server granted it, and nothing in the app carries
// a typed price or amount.

private final class RequestBox: @unchecked Sendable {
    var requests: [URLRequest] = []
    var bodies: [Data] = []
}

/// Serves one canned answer per test through a real `APIClient` and `URLSession`.
private final class PaymentsMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var json = "{}"
    nonisolated(unsafe) static var box = RequestBox()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.box.requests.append(request)
        Self.box.bodies.append(Self.readBody(request))
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession moves `httpBody` into a stream before a protocol sees it.
    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

@MainActor
private func mockClient(status: Int, json: String, box: RequestBox) -> APIClient {
    PaymentsMockURLProtocol.status = status
    PaymentsMockURLProtocol.json = json
    PaymentsMockURLProtocol.box = box
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PaymentsMockURLProtocol.self]
    return APIClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: config))
}

private func bodyJSON(_ box: RequestBox) -> [String: String] {
    guard let data = box.bodies.first,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
    return object
}


@MainActor
final class ExportUnlockServiceTests: XCTestCase {
    func testUnlockSendsTheIOSHeaderAndOptimizationId() async throws {
        let box = RequestBox()
        let service = ExportUnlockService(apiClient: mockClient(status: 200, json: #"{"status":"unlocked","balance":4}"#, box: box))

        let response = try await service.unlock(optimizationId: "opt-1", token: "tok")

        XCTAssertEqual(response, .init(status: "unlocked", balance: 4))
        let request = try XCTUnwrap(box.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/exports/unlock")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Resumely-Client"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(bodyJSON(box), ["optimizationId": "opt-1"])
    }

    func testUngatedAnswerHasNoBalance() async throws {
        let service = ExportUnlockService(apiClient: mockClient(status: 200, json: #"{"status":"ungated","balance":null}"#, box: RequestBox()))
        let response = try await service.unlock(optimizationId: "opt-1", token: "tok")
        XCTAssertEqual(response, .init(status: "ungated", balance: nil))
    }

    func test402OpensThePaywall() async {
        let service = ExportUnlockService(apiClient: mockClient(status: 402, json: #"{"error":"export_credits_required","balance":0}"#, box: RequestBox()))
        do {
            _ = try await service.unlock(optimizationId: "opt-1", token: "tok")
            XCTFail("expected creditsRequired")
        } catch {
            XCTAssertEqual(error as? ExportCreditsError, .creditsRequired)
        }
    }

    func test401AccountRequiredIsNotAStaleToken() async {
        let service = ExportUnlockService(apiClient: mockClient(status: 401, json: #"{"error":"account_required"}"#, box: RequestBox()))
        do {
            _ = try await service.unlock(optimizationId: "opt-1", token: "tok")
            XCTFail("expected accountRequired")
        } catch {
            XCTAssertEqual(error as? ExportCreditsError, .accountRequired)
        }
    }

    func testPlain401IsUnauthorizedSoTheTokenRefreshes() async {
        let service = ExportUnlockService(apiClient: mockClient(status: 401, json: #"{"error":"Unauthorized"}"#, box: RequestBox()))
        do {
            _ = try await service.unlock(optimizationId: "opt-1", token: "tok")
            XCTFail("expected unauthorized")
        } catch APIClientError.unauthorized {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testExportFailureCodesNameTheRefusal() {
        XCTAssertEqual(ExportFailureCode.code(for: ExportCreditsError.creditsRequired), "export_credits_required")
        XCTAssertEqual(ExportFailureCode.code(for: ExportCreditsError.accountRequired), "account_required")
        XCTAssertEqual(FailureReason.reason(for: ExportCreditsError.creditsRequired), "entitlement")
        XCTAssertEqual(FailureReason.reason(for: ExportCreditsError.accountRequired), "auth")
    }

    func testPaymentRequiredCopyNamesTheExportCreditNotAPlan() {
        // EXD-018: no "Premium" or plan wording anywhere.
        let message = APIClientError.paymentRequired.localizedDescription
        XCTAssertFalse(message.localizedCaseInsensitiveContains("upgrade"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("plan"))
    }
}

@MainActor
final class ReceiptVerifierTests: XCTestCase {
    func testSendsTheSignedTransactionNotAnAmount() async throws {
        let box = RequestBox()
        let verifier = ReceiptVerifier(apiClient: mockClient(
            status: 200,
            json: #"{"success":true,"status":"granted","creditsGranted":5,"balance":6}"#,
            box: box
        ))

        let result = try await verifier.verify(signedTransaction: "jws.payload.sig", productId: "resumely.exports.5", token: "tok")

        XCTAssertEqual(result, PurchaseVerification(status: "granted", creditsGranted: 5, balance: 6))
        let request = try XCTUnwrap(box.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/iap/verify")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Resumely-Client"), "ios")
        XCTAssertEqual(bodyJSON(box), ["signedTransaction": "jws.payload.sig", "productId": "resumely.exports.5"])
    }

    func testRevokedIsTerminal() async {
        let verifier = ReceiptVerifier(apiClient: mockClient(status: 409, json: #"{"error":"transaction_revoked"}"#, box: RequestBox()))
        do {
            _ = try await verifier.verify(signedTransaction: "j", productId: "resumely.exports.1", token: "t")
            XCTFail("expected revoked")
        } catch {
            XCTAssertEqual(error as? ReceiptVerifierError, .revoked)
        }
    }

    func testOtherRefusalsAreRetriable() async {
        let verifier = ReceiptVerifier(apiClient: mockClient(status: 403, json: #"{"error":"account_mismatch"}"#, box: RequestBox()))
        do {
            _ = try await verifier.verify(signedTransaction: "j", productId: "resumely.exports.1", token: "t")
            XCTFail("expected notGranted")
        } catch {
            XCTAssertEqual(error as? ReceiptVerifierError, .notGranted(status: 403, code: "account_mismatch"))
        }
    }
}

private actor EventLog {
    var events: [String] = []
    func add(_ event: String) { events.append(event) }
}

private struct StubVerifier: PurchaseVerifying {
    let log: EventLog
    let outcome: Result<PurchaseVerification, Error>
    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        await log.add("verify:\(productId):\(token)")
        return try outcome.get()
    }
}

private actor SequenceVerifierState {
    var outcomes: [Result<PurchaseVerification, Error>]
    init(_ outcomes: [Result<PurchaseVerification, Error>]) { self.outcomes = outcomes }
    func next() -> Result<PurchaseVerification, Error> { outcomes.removeFirst() }
}

private struct SequenceVerifier: PurchaseVerifying {
    let log: EventLog
    let state: SequenceVerifierState
    init(log: EventLog, outcomes: [Result<PurchaseVerification, Error>]) {
        self.log = log
        self.state = SequenceVerifierState(outcomes)
    }
    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        await log.add("verify:\(productId):\(token)")
        return try await state.next().get()
    }
}

@MainActor
final class PurchaseDeliveryTests: XCTestCase {
    private let account = PurchaseAccount(userId: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, token: "tok")
    private let granted = PurchaseVerification(status: "granted", creditsGranted: 5, balance: 6)

    func testFinishesOnlyAfterTheServerGranted() async {
        let log = EventLog()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.5",
            account: account,
            verifier: StubVerifier(log: log, outcome: .success(granted)),
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .finish(granted))
        let events = await log.events
        XCTAssertEqual(events, ["verify:resumely.exports.5:tok", "finish"])
    }

    func testAServerRefusalLeavesTheTransactionUnfinished() async {
        let log = EventLog()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.5",
            account: account,
            verifier: StubVerifier(log: log, outcome: .failure(ReceiptVerifierError.notGranted(status: 503, code: "iap_verification_unavailable"))),
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .keep(reason: "503_iap_verification_unavailable"))
        let events = await log.events
        XCTAssertFalse(events.contains("finish"))
    }

    func testANetworkFailureLeavesTheTransactionUnfinished() async {
        let log = EventLog()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.1",
            account: account,
            verifier: StubVerifier(log: log, outcome: .failure(URLError(.notConnectedToInternet))),
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .keep(reason: "network"))
        let events = await log.events
        XCTAssertFalse(events.contains("finish"))
    }

    func testARevokedTransactionIsFinishedSoItStopsComingBack() async {
        let log = EventLog()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.1",
            account: account,
            verifier: StubVerifier(log: log, outcome: .failure(ReceiptVerifierError.revoked)),
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .finishRevoked)
        let events = await log.events
        XCTAssertEqual(events.last, "finish")
    }

    func testAnExpiredTokenIsRefreshedOnceForTheSameAccount() async {
        let log = EventLog()
        let verifier = SequenceVerifier(log: log, outcomes: [
            .failure(ReceiptVerifierError.notGranted(status: 401, code: "Unauthorized")),
            .success(granted),
        ])
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.5",
            account: account,
            verifier: verifier,
            refreshAccount: { PurchaseAccount(userId: self.account.userId, token: "fresh") },
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .finish(granted))
        let events = await log.events
        XCTAssertEqual(events, ["verify:resumely.exports.5:tok", "verify:resumely.exports.5:fresh", "finish"])
    }

    func testARefreshThatLandsOnAnotherAccountIsNotUsed() async {
        let log = EventLog()
        let verifier = SequenceVerifier(log: log, outcomes: [
            .failure(ReceiptVerifierError.notGranted(status: 401, code: "Unauthorized")),
            .success(granted),
        ])
        let other = PurchaseAccount(userId: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!, token: "other")
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.5",
            account: account,
            verifier: verifier,
            refreshAccount: { other },
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .keep(reason: "401_token_expired"))
        let events = await log.events
        XCTAssertEqual(events, ["verify:resumely.exports.5:tok"])
    }

    func testWithNoAccountNothingIsSentOrFinished() async {
        let log = EventLog()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: "jws",
            productID: "resumely.exports.1",
            account: nil,
            verifier: StubVerifier(log: log, outcome: .success(granted)),
            finish: { await log.add("finish") }
        )
        XCTAssertEqual(decision, .keep(reason: "no_account"))
        let events = await log.events
        XCTAssertTrue(events.isEmpty)
    }
}

@MainActor
final class ExportCreditProductsTests: XCTestCase {
    func testThreePacksInDisplayOrder() {
        XCTAssertEqual(ExportCreditProducts.orderedIDs, ["resumely.exports.1", "resumely.exports.5", "resumely.exports.10"])
        XCTAssertEqual(ExportCreditProducts.orderedIDs.map { ExportCreditProducts.credits(for: $0) }, [1, 5, 10])
    }

    func testOldProductIdsAreNeverSold() {
        for id in ["credits_basic", "credits_saver", "credits_super"] {
            XCTAssertNil(ExportCreditProducts.credits(for: id))
        }
    }

    func testOnlyARealAccountCanBuy() {
        let userId = "11111111-1111-4111-8111-111111111111"
        let account = AuthSession(accessToken: "tok", refreshToken: "r", userId: userId, email: "a@example.com")
        XCTAssertEqual(PurchaseAccount(session: account), PurchaseAccount(userId: UUID(uuidString: userId)!, token: "tok"))

        let anonymous = AuthSession(accessToken: "tok", refreshToken: "r", userId: userId, email: nil, isAnonymous: true)
        XCTAssertNil(PurchaseAccount(session: anonymous))
        XCTAssertNil(PurchaseAccount(session: nil))
        XCTAssertNil(PurchaseAccount(session: AuthSession(accessToken: "tok", refreshToken: "r", userId: "not-a-uuid", email: nil)))
    }

    func testPaywallEventsCarryNoPersonalData() {
        let shown = AnalyticsEvent.paywallShown(optimizationId: "opt-1", balance: 0)
        XCTAssertEqual(shown.name, "paywall_shown")
        XCTAssertEqual(shown.properties, ["optimization_id": "opt-1", "balance": "0"])

        let completed = AnalyticsEvent.purchaseCompleted(productId: "resumely.exports.5", price: "12.99", currency: "USD", creditsGranted: 5)
        XCTAssertEqual(completed.name, "purchase_completed")
        XCTAssertEqual(completed.properties, [
            "product_id": "resumely.exports.5", "price": "12.99", "currency": "USD", "credits_granted": "5",
        ])
        XCTAssertEqual(AnalyticsEvent.purchaseCancelled(productId: "resumely.exports.1").name, "purchase_cancelled")
        XCTAssertEqual(AnalyticsEvent.purchasePending(productId: "resumely.exports.1").name, "purchase_pending")
        XCTAssertEqual(AnalyticsEvent.paywallDismissed(optimizationId: "o", balance: 0).name, "paywall_dismissed")
    }
}

@MainActor
final class ExportActionGateTests: XCTestCase {
    /// Spec 12: a 402 on export opens the paywall and never produces a file,
    /// styled or local (E5, E6).
    func testA402StopsTheExportBeforeAnyFileIsMade() async throws {
        let optimizationId = "gate-402-\(UUID().uuidString)"
        let box = RequestBox()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")
        let viewModel = OptimizedResumeViewModel(optimizationId: optimizationId)
        let exportsDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ResumeBuilderExports", isDirectory: true)
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: exportsDirectory.path)) ?? [])

        do {
            _ = try await ResumeExportAction.exportPDF(
                viewModel: viewModel,
                appState: appState,
                renderedHTML: "<html><body><p>Résumé</p></body></html>",
                analytics: AnalyticsService(transport: NoopTransport()),
                unlockService: ExportUnlockService(
                    apiClient: mockClient(status: 402, json: #"{"error":"export_credits_required","balance":0}"#, box: box)
                )
            )
            XCTFail("expected the paywall error")
        } catch {
            XCTAssertEqual(error as? ExportCreditsError, .creditsRequired)
        }

        XCTAssertEqual(box.requests.count, 1, "the unlock call is the only request")
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: exportsDirectory.path)) ?? [])
        XCTAssertEqual(after.subtracting(before), [], "no export file may be written after a 402")
    }
}

private struct NoopTransport: AnalyticsTransport {
    func capture(event: String, properties: [String: String], distinctId: String) async throws {}
    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {}
    func identify(distinctId: String, userProperties: [String: String]) async throws {}
}
