import StoreKit
import StoreKitTest
import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S2: the real StoreKit 2 calls against `Resumely.storekit`
// (buy, renew, expire, refund, restore). The server is a stub: these tests
// check what the app sends and when it finishes, not what the server grants.

/// Whether `StoreKitSessionTests` may run. On the iOS 26.5 simulator runtime
/// storekitd refuses StoreKit Testing ("is not installed for development"),
/// from `xcodebuild` and from Xcode alike (Apple forums threads 826364, 826971),
/// so an ordinary run skips them. The `StoreKitRequired` test plan sets
/// `REQUIRE_STOREKIT_TESTS=1`, and there a file that did not load is a failure:
/// a skip would read as evidence. Run that plan on a real device or an older
/// simulator runtime.
enum StoreKitTestGate: Equatable {
    case run, skip, fail

    /// Exists only in `Resumely.storekit`. The real products cannot prove the
    /// file loaded: once they exist in App Store Connect the App Store answers
    /// for them, and a test that goes on to buy one hangs on a real purchase
    /// (seen 2026-10-31).
    static let localOnlyProductID = "resumely.test.local-only"

    static var isRequired: Bool {
        ProcessInfo.processInfo.environment["REQUIRE_STOREKIT_TESTS"] == "1"
    }

    static func decide(productsLoaded: Bool, required: Bool) -> StoreKitTestGate {
        if productsLoaded { return .run }
        return required ? .fail : .skip
    }
}

private struct StoreKitProductsNotLoaded: LocalizedError {
    var errorDescription: String? {
        "REQUIRE_STOREKIT_TESTS=1 but Resumely.storekit did not load, so this case did not run."
    }
}

@MainActor
final class StoreKitTestGateTests: XCTestCase {
    func testLoadedProductsAlwaysRun() {
        XCTAssertEqual(StoreKitTestGate.decide(productsLoaded: true, required: false), .run)
        XCTAssertEqual(StoreKitTestGate.decide(productsLoaded: true, required: true), .run)
    }

    func testAnOrdinaryRunSkipsWithoutProducts() {
        XCTAssertEqual(StoreKitTestGate.decide(productsLoaded: false, required: false), .skip)
    }

    func testARequiredRunFailsWithoutProducts() {
        XCTAssertEqual(StoreKitTestGate.decide(productsLoaded: false, required: true), .fail)
    }

    func testOnlyTheLocalFileSellsTheProbeProduct() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Resumely", withExtension: "storekit"))
        let file = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(file.contains(StoreKitTestGate.localOnlyProductID))
        XCTAssertFalse(ResumelyProducts.isDeliverable(StoreKitTestGate.localOnlyProductID))
    }

    /// The founder's run proves 10 cases. A new case must update that count.
    func testTheRequiredRunCoversTenCases() {
        XCTAssertEqual(StoreKitSessionTests.defaultTestSuite.testCaseCount, 10)
    }
}

private actor VerifyLog {
    var productIDs: [String] = []
    func add(_ id: String) { productIDs.append(id) }
}

private struct RecordingVerifier: PurchaseVerifying {
    let log: VerifyLog
    let outcome: Result<PurchaseVerification, ReceiptVerifierError>
    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        await log.add(productId)
        return try outcome.get()
    }
}

@MainActor
final class StoreKitSessionTests: XCTestCase {
    private var session: SKTestSession!
    private let account = PurchaseAccount(userId: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!, token: "tok")
    private let proGranted = PurchaseVerification(
        status: "granted",
        creditsGranted: 0,
        balance: nil,
        entitlement: SubscriptionEntitlement(active: true, productId: ResumelyProducts.proMonthly, expiresAt: "2026-11-29T10:00:00Z")
    )

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Resumely")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let probe = try await Product.products(for: [StoreKitTestGate.localOnlyProductID])
        switch StoreKitTestGate.decide(productsLoaded: !probe.isEmpty, required: StoreKitTestGate.isRequired) {
        case .run:
            break
        case .skip:
            throw XCTSkip("StoreKit test file not loaded (iOS 26.5 simulator). Run the StoreKit Tests scheme on a device.")
        case .fail:
            throw StoreKitProductsNotLoaded()
        }
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    private func makeStore(log: VerifyLog, outcome: Result<PurchaseVerification, ReceiptVerifierError>) -> StoreKitManager {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "storekit-session-\(UUID().uuidString)")!)
        store.verifier = RecordingVerifier(log: log, outcome: outcome)
        let account = account
        store.accountProvider = { _ in account }
        return store
    }

    private func unfinishedCount() async -> Int {
        var count = 0
        for await _ in Transaction.unfinished { count += 1 }
        return count
    }

    func testLoadsTwoPacksThenProAndNoRetiredPack() async throws {
        let store = makeStore(log: VerifyLog(), outcome: .success(proGranted))
        try await store.loadProducts()

        XCTAssertEqual(store.products.map(\.id), ["resumely.exports.14", "resumely.exports.5.v2", "resumely.pro.monthly"])
        XCTAssertEqual(store.products.map(\.type), [.consumable, .consumable, .autoRenewable])
        XCTAssertEqual(store.products.last?.subscription?.subscriptionPeriod.unit, .month)
    }

    func testBuyingProSendsItAndFinishesOnlyAfterTheGrant() async throws {
        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))
        var planChanges = 0
        store.onPlanChanged = { planChanges += 1 }
        try await store.loadProducts()
        let pro = try XCTUnwrap(store.products.first { $0.id == ResumelyProducts.proMonthly })

        let result = try await store.purchase(pro, account: account)

        XCTAssertEqual(result, .granted(proGranted))
        let sent = await log.productIDs
        XCTAssertEqual(sent, [ResumelyProducts.proMonthly])
        XCTAssertEqual(planChanges, 1)
        let unfinished = await unfinishedCount()
        XCTAssertEqual(unfinished, 0)
        let latest = await Transaction.latest(for: ResumelyProducts.proMonthly)
        guard case .verified(let transaction) = latest else { return XCTFail("no verified Pro transaction") }
        XCTAssertEqual(transaction.appAccountToken, account.userId)
    }

    func testProOfAnotherAccountIsNotFinishedAndDoesNotLock() async throws {
        let store = makeStore(log: VerifyLog(), outcome: .failure(.ownedByAnotherAccount))
        try await store.loadProducts()
        let pro = try XCTUnwrap(store.products.first { $0.id == ResumelyProducts.proMonthly })

        do {
            _ = try await store.purchase(pro, account: account)
            XCTFail("expected ownedByAnotherAccount")
        } catch {
            XCTAssertEqual(error as? StoreKitManagerError, .ownedByAnotherAccount)
        }
        let unfinished = await unfinishedCount()
        XCTAssertEqual(unfinished, 1)
        XCTAssertNil(store.pendingProductID(for: account.userId))
    }

    func testAPackIsStillAConsumableGrant() async throws {
        let log = VerifyLog()
        let granted = PurchaseVerification(status: "granted", creditsGranted: 14, balance: 17)
        let store = makeStore(log: log, outcome: .success(granted))
        try await store.loadProducts()
        let pack = try XCTUnwrap(store.products.first { $0.id == ResumelyProducts.exports14 })

        let result = try await store.purchase(pack, account: account)

        XCTAssertEqual(result, .granted(granted))
        let sent = await log.productIDs
        XCTAssertEqual(sent, [ResumelyProducts.exports14])
    }

    func testRefreshSendsTheCurrentPlanOnly() async throws {
        _ = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        _ = try await session.buyProduct(identifier: ResumelyProducts.exports5, options: [.appAccountToken(account.userId)])
        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))
        var planChanges = 0
        store.onPlanChanged = { planChanges += 1 }

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .recorded(proGranted.entitlement!))
        let sent = await log.productIDs
        XCTAssertEqual(sent, [ResumelyProducts.proMonthly])
        XCTAssertEqual(planChanges, 1)
    }

    func testARenewalIsSentAsTheCurrentPlan() async throws {
        let first = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        try session.forceRenewalOfSubscription(productIdentifier: ResumelyProducts.proMonthly)
        let latest = await Transaction.latest(for: ResumelyProducts.proMonthly)
        guard case .verified(let renewal) = latest else { return XCTFail("no verified renewal") }
        XCTAssertNotEqual(renewal.id, first.id)
        XCTAssertEqual(renewal.originalID, first.originalID)

        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))
        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .recorded(proGranted.entitlement!))
        let sent = await log.productIDs
        XCTAssertEqual(sent, [ResumelyProducts.proMonthly])
    }

    func testAnExpiredPlanIsNotSent() async throws {
        _ = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        try session.expireSubscription(productIdentifier: ResumelyProducts.proMonthly)
        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))
        var planChanges = 0
        store.onPlanChanged = { planChanges += 1 }

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .noPlan)
        let sent = await log.productIDs
        XCTAssertEqual(sent, [])
        XCTAssertEqual(planChanges, 1, "a plan that ended re-reads the server")
    }

    func testARefundedPlanIsNotSent() async throws {
        let transaction = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        try session.refundTransaction(identifier: UInt(transaction.id))
        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .noPlan)
        let sent = await log.productIDs
        XCTAssertEqual(sent, [])
    }

    func testRestoreOnAnotherAccountNamesTheOwner() async throws {
        _ = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        let store = makeStore(log: VerifyLog(), outcome: .failure(.ownedByAnotherAccount))

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .ownedByAnotherAccount)
    }

    func testGuestsSendNothing() async throws {
        _ = try await session.buyProduct(identifier: ResumelyProducts.proMonthly, options: [.appAccountToken(account.userId)])
        let log = VerifyLog()
        let store = makeStore(log: log, outcome: .success(proGranted))
        store.accountProvider = { _ in nil }

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .noAccount)
        let sent = await log.productIDs
        XCTAssertEqual(sent, [])
    }
}
