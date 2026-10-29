import StoreKit
import StoreKitTest
import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S2: the real StoreKit 2 calls against `Resumely.storekit`
// (buy, renew, expire, refund, restore). The server is a stub: these tests
// check what the app sends and when it finishes, not what the server grants.

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
        // `xcodebuild test` on iOS 26.5 does not hand the .storekit file to the
        // simulator's storekitd (Apple forums thread 826971), so no product
        // loads. These tests run from Xcode (Product > Test); from the command
        // line they skip instead of failing.
        let probe = try await Product.products(for: [ResumelyProducts.proMonthly])
        if probe.isEmpty {
            throw XCTSkip("StoreKit test file not loaded (xcodebuild on iOS 26.5). Run from Xcode.")
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

        let outcome = await store.refreshEntitlements()

        XCTAssertEqual(outcome, .noPlan)
        let sent = await log.productIDs
        XCTAssertEqual(sent, [])
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
