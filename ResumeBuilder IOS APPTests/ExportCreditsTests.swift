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

    func testUnexpectedFailureDoesNotExposeTheServerCode() async {
        let service = ExportUnlockService(apiClient: mockClient(status: 500, json: #"{"error":"failed_to_unlock_export"}"#, box: RequestBox()))
        do {
            _ = try await service.unlock(optimizationId: "opt-1", token: "tok")
            XCTFail("expected server error")
        } catch APIClientError.serverError(let status, let message) {
            XCTAssertEqual(status, 500)
            XCTAssertFalse(message.contains("failed_to_unlock_export"))
            XCTAssertFalse(message.contains("export_unlock_failed"))
        } catch { XCTFail("unexpected \(error)") }
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

    func testA402NeverFetchesTheStyledHTML() async throws {
        let box = RequestBox()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")
        var loaderCalled = false

        _ = try? await ResumeExportAction.exportPDF(
            viewModel: OptimizedResumeViewModel(optimizationId: "gate-402-loader-\(UUID().uuidString)"),
            appState: appState,
            loadStyledHTML: {
                loaderCalled = true
                return "<html><body><p>Résumé</p></body></html>"
            },
            analytics: AnalyticsService(transport: NoopTransport()),
            unlockService: ExportUnlockService(
                apiClient: mockClient(status: 402, json: #"{"error":"export_credits_required","balance":0}"#, box: box)
            )
        )

        XCTAssertFalse(loaderCalled)
    }

    /// Codex P1 on #214: signed in, the design load fails, the token refresh is
    /// rejected and signs out. With preview HTML on hand, the export must stop:
    /// no file, no export_success, no silent guest export.
    func testAnExportThatLostItsSessionStopsInsteadOfExportingAsAGuest() async throws {
        let optimizationId = "lost-session-\(UUID().uuidString)"
        let box = RequestBox()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")
        let beganSignedIn = appState.session != nil
        // What the rejected refresh's sign-out leaves behind.
        appState.session = nil
        let transport = RecordingTransport()
        let exportsDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ResumeBuilderExports", isDirectory: true)
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: exportsDirectory.path)) ?? [])

        do {
            _ = try await ResumeExportAction.exportPDF(
                viewModel: OptimizedResumeViewModel(optimizationId: optimizationId),
                appState: appState,
                renderedHTML: "<html><body><h1>Dana Levi</h1><p>Senior iOS engineer, Swift and SwiftUI.</p></body></html>",
                beganSignedIn: beganSignedIn,
                analytics: AnalyticsService(transport: transport),
                unlockService: ExportUnlockService(
                    apiClient: mockClient(status: 200, json: #"{"status":"unlocked","balance":4}"#, box: box)
                )
            )
            XCTFail("expected the export to stop")
        } catch {
            guard case APIClientError.unauthorized = error else {
                return XCTFail("expected unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(box.requests.count, 0, "no unlock is attempted without a session")
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: exportsDirectory.path)) ?? [])
        XCTAssertEqual(after.subtracting(before), [], "no export file may be written")
        _ = try await transport.waitForEvent("export_failed")
        XCTAssertFalse(transport.events.contains { $0.name == "export_success" })
    }

    /// A real guest (no session from the start) still gets the local export.
    func testAGuestExportStillSkipsTheUnlock() async throws {
        let box = RequestBox()
        let appState = AppState()
        appState.session = nil

        let result = try await ResumeExportAction.exportPDF(
            viewModel: OptimizedResumeViewModel(optimizationId: "guest-\(UUID().uuidString)"),
            appState: appState,
            renderedHTML: "<html><body><h1>Dana Levi</h1><p>Senior iOS engineer, Swift and SwiftUI.</p></body></html>",
            beganSignedIn: false,
            analytics: AnalyticsService(transport: NoopTransport()),
            unlockService: ExportUnlockService(
                apiClient: mockClient(status: 200, json: #"{"status":"unlocked","balance":4}"#, box: box)
            )
        )

        XCTAssertEqual(box.requests.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
    }

    /// Before the preview finishes, export fetches the styled HTML and renders it on
    /// the phone, so the PDF keeps the chosen design instead of the server's layout.
    func testExportBeforeThePreviewLoadsUsesFetchedStyledHTMLNotTheServer() async throws {
        let box = RequestBox()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")
        let transport = RecordingTransport()

        let result = try await ResumeExportAction.exportPDF(
            viewModel: OptimizedResumeViewModel(optimizationId: "fetched-\(UUID().uuidString)"),
            appState: appState,
            renderedHTML: nil,
            loadStyledHTML: { "<html><body><h1>Dana Levi</h1><p>Senior iOS engineer, Swift and SwiftUI.</p></body></html>" },
            analytics: AnalyticsService(transport: transport),
            unlockService: ExportUnlockService(
                apiClient: mockClient(status: 200, json: #"{"status":"unlocked","balance":4}"#, box: box)
            )
        )

        XCTAssertEqual(box.requests.count, 1, "the unlock call is the only request; no /api/download")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        let success = try await transport.waitForEvent("export_success")
        XCTAssertEqual(success["pdf_path"], "styled_fetched")
    }

    func testExportWithLoadedPreviewReportsThePreviewPath() async throws {
        let box = RequestBox()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")
        let transport = RecordingTransport()
        var loaderCalled = false

        _ = try await ResumeExportAction.exportPDF(
            viewModel: OptimizedResumeViewModel(optimizationId: "preview-\(UUID().uuidString)"),
            appState: appState,
            renderedHTML: "<html><body><h1>Dana Levi</h1><p>Senior iOS engineer, Swift and SwiftUI.</p></body></html>",
            loadStyledHTML: {
                loaderCalled = true
                return nil
            },
            analytics: AnalyticsService(transport: transport),
            unlockService: ExportUnlockService(
                apiClient: mockClient(status: 200, json: #"{"status":"unlocked","balance":4}"#, box: box)
            )
        )

        XCTAssertFalse(loaderCalled, "a loaded preview is used as-is")
        XCTAssertEqual(box.requests.count, 1)
        let success = try await transport.waitForEvent("export_success")
        XCTAssertEqual(success["pdf_path"], "styled_preview")
    }
}

/// @unchecked Sendable is safe here because tests touch it from the MainActor only.
private final class RecordingTransport: AnalyticsTransport, @unchecked Sendable {
    var events: [(name: String, properties: [String: String])] = []

    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        events.append((event, properties))
    }
    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {}
    func identify(distinctId: String, userProperties: [String: String]) async throws {}

    /// `AnalyticsService.track` delivers on a detached Task, so poll briefly.
    @MainActor
    func waitForEvent(_ name: String) async throws -> [String: String] {
        for _ in 0..<50 {
            if let match = events.first(where: { $0.name == name }) { return match.properties }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("\(name) was never captured")
        return [:]
    }
}

private struct NoopTransport: AnalyticsTransport {
    func capture(event: String, properties: [String: String], distinctId: String) async throws {}
    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {}
    func identify(distinctId: String, userProperties: [String: String]) async throws {}
}

@MainActor
final class PendingPurchaseLockTests: XCTestCase {
    private let buyer = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let other = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PendingPurchaseLockTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testALockSurvivesARelaunch() {
        StoreKitManager(defaults: defaults).setPendingLock(userId: buyer, productID: "resumely.exports.5")
        let relaunched = StoreKitManager(defaults: defaults)
        XCTAssertEqual(relaunched.pendingProductID(for: buyer), "resumely.exports.5")
    }

    func testTheLockAppliesOnlyToTheBuyer() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.1")
        XCTAssertNil(store.pendingProductID(for: other))
        XCTAssertNil(store.pendingProductID(for: nil))
        store.clearPendingLock(for: other, productID: "resumely.exports.1")
        XCTAssertEqual(store.pendingProductID(for: buyer), "resumely.exports.1", "another account cannot clear it")
    }

    func testTheLockExpires() {
        let store = StoreKitManager(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_761_000_000)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.10", now: start)
        XCTAssertEqual(store.pendingProductID(for: buyer, now: start.addingTimeInterval(47 * 3600)), "resumely.exports.10")
        XCTAssertNil(store.pendingProductID(for: buyer, now: start.addingTimeInterval(49 * 3600)))
    }

    func testClearingRemovesTheSavedLock() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        store.clearPendingLock(for: buyer, productID: "resumely.exports.5")
        XCTAssertNil(StoreKitManager(defaults: defaults).pendingProductID(for: buyer))
    }

    func testAGrantForAnotherPackKeepsTheLock() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        store.recordDelivery(.finish(granted), buyer: buyer, productID: "resumely.exports.1")
        XCTAssertEqual(store.pendingProductID(for: buyer), "resumely.exports.5")
        store.recordDelivery(.finish(granted), buyer: buyer, productID: "resumely.exports.5")
        XCTAssertNil(store.pendingProductID(for: buyer))
    }

    func testABackgroundDeliveryThatFailsLocksTheBuyer() {
        let store = StoreKitManager(defaults: defaults)
        store.recordDelivery(.keep(reason: "503_iap_verification_unavailable"), buyer: buyer, productID: "resumely.exports.1")
        XCTAssertEqual(store.pendingProductID(for: buyer), "resumely.exports.1")
        XCTAssertNil(store.pendingProductID(for: other))
        XCTAssertEqual(StoreKitManager(defaults: defaults).pendingProductID(for: buyer), "resumely.exports.1", "saved for a relaunch")
    }

    func testAFailedDeliveryDoesNotReplaceAWaitingLock() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.10")
        store.recordDelivery(.keep(reason: "network"), buyer: buyer, productID: "resumely.exports.1")
        XCTAssertEqual(store.pendingProductID(for: buyer), "resumely.exports.10")
    }

    func testAFailedDeliveryWithNoBuyerLocksNobody() {
        let store = StoreKitManager(defaults: defaults)
        store.recordDelivery(.keep(reason: "no_account"), buyer: nil, productID: "resumely.exports.1")
        XCTAssertTrue(store.pendingLocks.isEmpty)
    }

    func testEachAccountsPendingPurchaseSurvivesAnotherAccountsPurchaseAndRelaunch() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        store.setPendingLock(userId: other, productID: "resumely.exports.1")
        let relaunched = StoreKitManager(defaults: defaults)
        XCTAssertEqual(relaunched.pendingProductID(for: buyer), "resumely.exports.5")
        XCTAssertEqual(relaunched.pendingProductID(for: other), "resumely.exports.1")
        relaunched.clearPendingLock(for: other, productID: "resumely.exports.1")
        XCTAssertEqual(StoreKitManager(defaults: defaults).pendingProductID(for: buyer), "resumely.exports.5")
    }

    func testLegacySingleLockIsKeptWhenReadingTheNewFormat() throws {
        let lock = StoreKitManager.PendingPurchaseLock(userId: buyer, productID: "resumely.exports.5", since: Date())
        defaults.set(try JSONEncoder().encode(lock), forKey: "storekit_pending_purchase_lock")
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: other, productID: "resumely.exports.1")
        let relaunched = StoreKitManager(defaults: defaults)
        XCTAssertEqual(relaunched.pendingProductID(for: buyer), "resumely.exports.5")
        XCTAssertEqual(relaunched.pendingProductID(for: other), "resumely.exports.1")
    }

    func testBackgroundGrantDoesNotPublishToAnotherAccountOrSignedOutSession() async {
        let store = StoreKitManager(defaults: defaults)
        var active: PurchaseAccount? = PurchaseAccount(userId: other, token: "b")
        store.accountProvider = { _ in active }
        var balances: [Int?] = []
        store.onCreditsGranted = { balances.append($0) }
        let switched = await store.publishBackgroundGrant(granted, for: buyer)
        XCTAssertFalse(switched)
        active = nil
        let signedOut = await store.publishBackgroundGrant(granted, for: buyer)
        XCTAssertFalse(signedOut)
        XCTAssertEqual(store.backgroundGrantCount, 0)
        XCTAssertTrue(balances.isEmpty)
        active = PurchaseAccount(userId: buyer, token: "a")
        let matching = await store.publishBackgroundGrant(granted, for: buyer)
        XCTAssertTrue(matching)
        XCTAssertEqual(store.backgroundGrantCount, 1)
        XCTAssertEqual(balances, [5])
    }

    func testARefundClearsTheLock() {
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        store.recordDelivery(.finishRevoked, buyer: buyer, productID: "resumely.exports.5")
        XCTAssertNil(store.pendingProductID(for: buyer))
    }

    private var granted: PurchaseVerification {
        PurchaseVerification(status: "granted", creditsGranted: 5, balance: 5)
    }
}


@MainActor
final class PendingPaywallRecoveryTests: XCTestCase {
    private let buyer = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

    func testOpeningALockedPaywallDeliversBeforeLoadingPricesAndResumesTheExport() async {
        let suite = "PendingPaywallRecovery-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreKitManager(defaults: defaults)
        store.accountProvider = { _ in PurchaseAccount(userId: self.buyer, token: "test") }
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        var retries = 0
        var priceLoads = 0
        let model = ExportPaywallModel(optimizationId: "opt", store: store, retryPendingPurchases: {
            retries += 1
            let grant = PurchaseVerification(status: "granted", creditsGranted: 5, balance: 5)
            store.recordDelivery(.finish(grant), buyer: self.buyer, productID: "resumely.exports.5")
            _ = await store.publishBackgroundGrant(grant, for: self.buyer)
        }, loadStoreProducts: { priceLoads += 1 })

        await model.load(for: buyer)

        XCTAssertEqual(retries, 1)
        XCTAssertEqual(priceLoads, 0, "delivered credits resume the export without another StoreKit price request")
        XCTAssertNil(store.pendingProductID(for: buyer))
        XCTAssertTrue(model.approvalGranted)
        XCTAssertEqual(model.phase, .awaitingApproval(productID: "resumely.exports.5"))
    }

    func testFailedRecoveryKeepsTheLockAndReopeningRetriesAgain() async {
        let suite = "PendingPaywallRecovery-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreKitManager(defaults: defaults)
        store.setPendingLock(userId: buyer, productID: "resumely.exports.5")
        var retries = 0
        let model = ExportPaywallModel(optimizationId: "opt", store: store,
            retryPendingPurchases: { retries += 1 }, loadStoreProducts: {})
        await model.load(for: buyer)
        await model.load(for: buyer)
        XCTAssertEqual(retries, 2)
        XCTAssertEqual(model.phase, .awaitingApproval(productID: "resumely.exports.5"))
        XCTAssertEqual(store.pendingProductID(for: buyer), "resumely.exports.5")
        XCTAssertFalse(model.approvalGranted)
    }

    func testNormalPaywallLoadsPricesWithoutRetryingUnrelatedPurchases() async {
        let suite = "PendingPaywallRecovery-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreKitManager(defaults: defaults)
        var retries = 0
        var priceLoads = 0
        let model = ExportPaywallModel(optimizationId: "opt", store: store,
            retryPendingPurchases: { retries += 1 }, loadStoreProducts: { priceLoads += 1 })
        await model.load(for: buyer)
        XCTAssertEqual(retries, 0)
        XCTAssertEqual(priceLoads, 1)
        XCTAssertEqual(model.phase, .ready)
    }
}
