import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class CreditsResponseOrderingTests: XCTestCase {
    func testTwoPackExportsKeepNewestBalanceWhenReadsReturnBackwards() async throws {
        try await assertTwoExportsKeepNewestUsage(pro: false)
    }

    func testTwoProExportsKeepNewestUsageWhenReadsReturnBackwards() async throws {
        try await assertTwoExportsKeepNewestUsage(pro: true)
    }

    func testUnlockInvalidatesAReadBeforeItsFollowUpReadFinishes() async throws {
        let (app, service, controller) = makeApp(pro: false)
        let oldRead = Task { await app.refreshCredits() }
        await controller.waitForReads(1)
        try await app.authorizeExport(optimizationId: "opt-1", service: service)
        await controller.waitForReads(2)
        let followUp = app.creditsRefreshAfterExport

        controller.reply(to: 0, json: credits(balance: 2))
        await oldRead.value
        XCTAssertEqual(app.creditsBalance, 1, "An earlier read cannot undo the unlock's balance.")
        controller.reply(to: 1, json: credits(balance: 1))
        await followUp?.value
        XCTAssertEqual(app.creditsBalance, 1)
    }

    func testAuthoritativePurchaseBalanceInvalidatesPendingRead() async {
        let (app, _, controller) = makeApp(pro: false)
        let read = Task { await app.refreshCredits() }
        await controller.waitForReads(1)
        app.applyCreditsBalance(5)
        controller.reply(to: 0, json: credits(balance: 2))
        await read.value
        XCTAssertEqual(app.creditsBalance, 5)
    }

    func testSignOutAndSameAccountSignInRejectOldRead() async {
        let (app, _, controller) = makeApp(pro: false)
        let original = app.session
        let read = Task { await app.refreshCredits() }
        await controller.waitForReads(1)
        app.signOut()
        app.session = original
        controller.reply(to: 0, json: credits(balance: 2))
        await read.value
        XCTAssertEqual(app.creditsBalance, 0)
        XCTAssertNil(app.subscription)
    }

    func testNilBalanceProUnlockStillInvalidatesEarlierUsageRead() async throws {
        let (app, service, controller) = makeApp(pro: true, balanceInUnlock: false)
        app.subscription = SubscriptionStatus(active: true, productId: nil, expiresAt: nil, autoRenew: nil, periodExports: 2, periodCap: 40)
        let oldRead = Task { await app.refreshCredits() }
        await controller.waitForReads(1)
        try await app.authorizeExport(optimizationId: "opt-1", service: service)
        await controller.waitForReads(2)
        let followUp = app.creditsRefreshAfterExport
        controller.reply(to: 0, json: credits(balance: 0, used: 1))
        await oldRead.value
        XCTAssertEqual(app.subscription?.periodExports, 2)
        controller.reply(to: 1, json: credits(balance: 0, used: 3))
        await followUp?.value
        XCTAssertEqual(app.subscription?.periodExports, 3)
    }

    private func assertTwoExportsKeepNewestUsage(pro: Bool) async throws {
        let (app, service, controller) = makeApp(pro: pro)
        try await app.authorizeExport(optimizationId: "opt-1", service: service)
        await controller.waitForReads(1)
        let firstRead = app.creditsRefreshAfterExport
        try await app.authorizeExport(optimizationId: "opt-2", service: service)
        await controller.waitForReads(2)
        let secondRead = app.creditsRefreshAfterExport

        controller.reply(to: 1, json: credits(balance: 0, used: pro ? 2 : nil))
        await secondRead?.value
        controller.reply(to: 0, json: credits(balance: 1, used: pro ? 1 : nil))
        await firstRead?.value

        XCTAssertEqual(app.creditsBalance, 0)
        XCTAssertEqual(app.subscription?.periodExports, pro ? 2 : nil)
    }

    private func makeApp(pro: Bool, balanceInUnlock: Bool = true) -> (AppState, ExportUnlockService, CreditsOrderController) {
        let controller = CreditsOrderController(pro: pro, balanceInUnlock: balanceInUnlock)
        OrderedCreditsURLProtocol.controller = controller
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OrderedCreditsURLProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: config))
        let app = AppState(apiClient: client)
        app.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: "user-1", email: nil)
        app.creditsBalance = 2
        return (app, ExportUnlockService(apiClient: client), controller)
    }

    private func credits(balance: Int, used: Int? = nil) -> String {
        let plan = used.map {
            #", "subscription":{"active":true,"productId":"resumely.pro.monthly","periodExports":\#($0),"periodCap":40}"#
        } ?? ""
        return #"{"balance":\#(balance),"transactions":[]\#(plan)}"#
    }
}

/// Holds each credits response until the test releases that exact request.
private final class CreditsOrderController: @unchecked Sendable {
    private let lock = NSLock()
    private let pro: Bool
    private let balanceInUnlock: Bool
    private var unlockCount = 0
    private var reads: [OrderedCreditsURLProtocol] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(pro: Bool, balanceInUnlock: Bool) {
        self.pro = pro
        self.balanceInUnlock = balanceInUnlock
    }

    func receive(_ request: OrderedCreditsURLProtocol) {
        if request.request.url?.path.hasSuffix("/exports/unlock") == true {
            let balance = lock.withLock {
                unlockCount += 1
                return pro ? 0 : max(0, 2 - unlockCount)
            }
            let source = pro ? "subscription" : "credit"
            let balanceField = balanceInUnlock ? #", "balance":\#(balance)"# : ""
            request.reply(#"{"status":"unlocked"\#(balanceField),"source":"\#(source)"}"#)
        } else {
            let ready = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
                reads.append(request)
                let ready = waiters.filter { $0.0 <= reads.count }.map(\.1)
                waiters.removeAll { $0.0 <= reads.count }
                return ready
            }
            ready.forEach { $0.resume() }
        }
    }

    func waitForReads(_ count: Int) async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock {
                if reads.count >= count { return true }
                waiters.append((count, continuation))
                return false
            }
            if ready { continuation.resume() }
        }
    }

    func reply(to index: Int, json: String) {
        let request = lock.withLock { reads[index] }
        request.reply(json)
    }
}

private final class OrderedCreditsURLProtocol: URLProtocol {
    nonisolated(unsafe) static var controller: CreditsOrderController?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.controller?.receive(self) }
    override func stopLoading() {}

    func reply(_ json: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
