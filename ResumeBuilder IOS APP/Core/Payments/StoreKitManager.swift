import Foundation
import Observation
import OSLog
import StoreKit

/// What the app sells (pricing v2, plan section 2). Prices live in App Store
/// Connect only: the app shows `product.displayPrice`, never a typed price.
enum ResumelyProducts {
    static let exports14 = "resumely.exports.14"
    static let exports5 = "resumely.exports.5.v2"
    static let proMonthly = "resumely.pro.monthly"

    /// Sale order (plan A2): the 14-pack first, then the 5-pack, then Pro.
    static let orderedIDs = [exports14, exports5, proMonthly]

    /// The v1 packs. Never loaded or sold again, but a paid transaction for one
    /// that is still unfinished is delivered: the server still grants it.
    static let retiredPackIDs = ["resumely.exports.1", "resumely.exports.5", "resumely.exports.10"]

    /// Exports in a pack on sale, or nil (retired packs, Pro, anything else).
    static func exports(for productID: String) -> Int? {
        switch productID {
        case exports14: return 14
        case exports5: return 5
        default: return nil
        }
    }

    static func isSubscription(_ productID: String) -> Bool {
        productID == proMonthly
    }

    /// A transaction the server can still act on: a pack on sale, a retired
    /// pack someone already paid for, or Pro (purchase, renewal, refund).
    static func isDeliverable(_ productID: String) -> Bool {
        exports(for: productID) != nil || retiredPackIDs.contains(productID) || isSubscription(productID)
    }
}

/// Who a purchase belongs to. Only a real account can buy: the Supabase user id
/// becomes the transaction's `appAccountToken`, and the server grants only when
/// they match (spec 7.2 check 6).
struct PurchaseAccount: Equatable, Sendable {
    let userId: UUID
    let token: String
}

/// What to do with a verified transaction once the server has answered.
enum PurchaseDelivery {
    enum Decision: Equatable {
        /// Server granted (or had already granted): finish the transaction.
        case finish(PurchaseVerification)
        /// Apple refunded it; it can never grant. Finish so it stops coming back.
        case finishRevoked
        /// Not granted yet (offline, server error, another account signed in).
        /// Leave it unfinished; it is re-sent at launch and on `Transaction.updates`.
        case keep(reason: String)
        /// Pro that belongs to another Resumely account. Left unfinished for
        /// that account, and never locks or retries for this one.
        case otherAccount
    }

    /// A `.keep` reason that a later retry can turn into a grant: no account
    /// yet, offline, an expired token, rate limiting or a server error.
    static func isRetryable(_ reason: String) -> Bool {
        reason == "no_account" || reason == "network"
            || reason.hasPrefix("401_") || reason.hasPrefix("429_") || reason.hasPrefix("5")
    }

    /// Sends the signed transaction to the server and decides, before anything
    /// is finished, whether it may be finished. `finish()` runs only on a grant
    /// (spec 7.1 steps 2 and 3): finishing first would lose a paid purchase if
    /// the grant then failed.
    static func deliver(
        signedTransaction: String,
        productID: String,
        account: PurchaseAccount?,
        verifier: PurchaseVerifying,
        refreshAccount: (() async -> PurchaseAccount?)? = nil,
        finish: () async -> Void
    ) async -> Decision {
        guard let account else { return .keep(reason: "no_account") }
        let decision: Decision
        do {
            let verification: PurchaseVerification
            do {
                verification = try await verifier.verify(
                    signedTransaction: signedTransaction,
                    productId: productID,
                    token: account.token
                )
            } catch ReceiptVerifierError.notGranted(status: 401, _) {
                // An expired access token (an Ask to Buy approval can land hours
                // later): refresh once and try again, for the same account only.
                guard let refreshed = await refreshAccount?(), refreshed.userId == account.userId else {
                    throw ReceiptVerifierError.notGranted(status: 401, code: "token_expired")
                }
                verification = try await verifier.verify(
                    signedTransaction: signedTransaction,
                    productId: productID,
                    token: refreshed.token
                )
            }
            decision = .finish(verification)
        } catch ReceiptVerifierError.revoked {
            decision = .finishRevoked
        } catch ReceiptVerifierError.ownedByAnotherAccount {
            decision = .otherAccount
        } catch ReceiptVerifierError.notGranted(let status, let code) {
            decision = .keep(reason: status == 0 ? code : "\(status)_\(code)")
        } catch {
            decision = .keep(reason: "network")
        }
        switch decision {
        case .finish, .finishRevoked:
            await finish()
        case .keep, .otherAccount:
            break
        }
        return decision
    }
}

enum StoreKitPurchaseResult: Equatable {
    case granted(PurchaseVerification)
    case cancelled
    /// Ask to Buy or a payment that needs approval; delivered later through
    /// `Transaction.updates`.
    case pending
}

enum StoreKitManagerError: LocalizedError, Equatable {
    case accountRequired
    case productUnavailable
    case unverifiedTransaction
    /// Paid, but the server has not granted yet. The transaction stays
    /// unfinished and is retried, so the credits are not lost.
    case grantPending
    /// Apple refunded the purchase before the server granted it (spec 8).
    case purchaseRefunded
    case purchaseFailed
    /// Pro on this Apple ID was bought under another Resumely account.
    case ownedByAnotherAccount

    var errorDescription: String? {
        switch self {
        case .ownedByAnotherAccount:
            return NSLocalizedString(
                "This subscription belongs to another Resumely account. Sign in with that account.",
                comment: "Restore or purchase of Pro under a different account"
            )
        case .accountRequired:
            return NSLocalizedString("Create a free account to buy export credits.", comment: "Purchase needs a real account")
        case .productUnavailable:
            return NSLocalizedString("Export credits are not available right now. Try again later.", comment: "StoreKit products did not load")
        case .unverifiedTransaction:
            return NSLocalizedString("Apple could not confirm this purchase.", comment: "StoreKit unverified transaction")
        case .grantPending:
            return NSLocalizedString("Your purchase went through. Your credits will appear shortly.", comment: "Paid but server grant not confirmed yet")
        case .purchaseRefunded:
            return NSLocalizedString("Apple refunded this purchase, so no credits were added.", comment: "Purchase refunded before the grant")
        case .purchaseFailed:
            return NSLocalizedString("The purchase did not complete. You were not charged.", comment: "StoreKit purchase failed")
        }
    }
}

/// StoreKit 2 for export packs and Pro (StoreKit spec 7.1 and 10.1, pricing v2).
/// The server decides when the paywall shows (a 402) and every export; this
/// class only loads products, buys, and delivers transactions to the server.
@Observable
@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()

    /// A purchase Apple holds (Ask to Buy) or charged without a server grant yet,
    /// for one account. Saved on the device so a relaunch keeps the paywall
    /// locked (Codex P1s on #207), scoped to the buyer so another account on the
    /// same phone is not blocked (Codex P2). Ask to Buy requests expire, so the
    /// lock does too.
    struct PendingPurchaseLock: Codable, Equatable {
        let userId: UUID
        let productID: String
        let since: Date
    }

    static let pendingLockLifetime: TimeInterval = 48 * 3600
    private static let pendingLockKey = "storekit_pending_purchase_lock"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.pendingLockKey),
           let locks = try? JSONDecoder().decode([PendingPurchaseLock].self, from: data) {
            pendingLocks = Dictionary(locks.map { ($0.userId, $0) }, uniquingKeysWith: { $1 })
        } else if let data = defaults.data(forKey: Self.pendingLockKey),
                  let lock = try? JSONDecoder().decode(PendingPurchaseLock.self, from: data) {
            // Preserve a pending purchase saved by the earlier single-lock build.
            pendingLocks[lock.userId] = lock
        }
    }

    private(set) var products: [Product] = []
    /// Counts grants delivered outside `purchase()` (Ask to Buy approvals,
    /// retries). A paywall waiting on an approval watches it to resume the export.
    private(set) var backgroundGrantCount = 0
    private(set) var pendingLocks: [UUID: PendingPurchaseLock] = [:]

    /// The product still waiting for this account, or nil (none, another
    /// account's, or expired).
    func pendingProductID(for userId: UUID?, now: Date = Date()) -> String? {
        guard let userId, let lock = pendingLocks[userId],
              now.timeIntervalSince(lock.since) < Self.pendingLockLifetime else { return nil }
        return lock.productID
    }

    /// Pro never locks: Apple cannot sell the same plan twice, and a Pro lock
    /// would block pack sales with nothing left to clear it (Codex on #226).
    func setPendingLock(userId: UUID, productID: String, now: Date = Date()) {
        guard !ResumelyProducts.isSubscription(productID) else { return }
        let lock = PendingPurchaseLock(userId: userId, productID: productID, since: now)
        pendingLocks[userId] = lock
        savePendingLocks(now: now)
    }

    /// Clears the lock only for the same account and pack, so a grant for an
    /// older pack cannot unlock a pack still waiting (second-model P1 on #207).
    func clearPendingLock(for userId: UUID?, productID: String) {
        guard let userId, pendingLocks[userId]?.productID == productID else { return }
        pendingLocks[userId] = nil
        savePendingLocks()
    }

    /// Persist all accounts' locks together; one account cannot erase another's.
    private func savePendingLocks(now: Date = Date()) {
        pendingLocks = pendingLocks.filter { now.timeIntervalSince($0.value.since) < Self.pendingLockLifetime }
        if pendingLocks.isEmpty {
            defaults.removeObject(forKey: Self.pendingLockKey)
        } else if let data = try? JSONEncoder().encode(Array(pendingLocks.values)) {
            defaults.set(data, forKey: Self.pendingLockKey)
        }
    }

    /// Lock bookkeeping after a background delivery. A transaction left
    /// unfinished (server down at launch, app killed before the grant) locks its
    /// buyer, so the paywall cannot sell again before it is delivered
    /// (second-model P1 on #207). A lock already waiting is kept. A grant or a
    /// refund clears the lock for that pack.
    ///
    /// Only a failure a retry can fix locks (offline, 5xx, an expired token,
    /// signed out); a permanent refusal (400, 403) would otherwise lock the
    /// paywall again every 48 hours (second-model on #226). Pro never locks
    /// (`setPendingLock`).
    func recordDelivery(_ decision: PurchaseDelivery.Decision, buyer: UUID?, productID: String) {
        switch decision {
        case .finish, .finishRevoked:
            clearPendingLock(for: buyer, productID: productID)
        case .keep(let reason):
            guard let buyer, pendingProductID(for: buyer) == nil,
                  PurchaseDelivery.isRetryable(reason) else { return }
            setPendingLock(userId: buyer, productID: productID)
        case .otherAccount:
            // The buyer's own account delivers it at sign-in; nothing to lock here.
            break
        }
    }
    var verifier: PurchaseVerifying = ReceiptVerifier()

    /// Set by `AppState` at launch: the account a delivery is made for, or nil
    /// when no real account is signed in (guests and anonymous sessions).
    /// `refresh: true` refreshes the access token first.
    @ObservationIgnored var accountProvider: (@MainActor (_ refresh: Bool) async -> PurchaseAccount?)?
    /// Called after a background delivery grants credits (new balance).
    @ObservationIgnored var onCreditsGranted: (@MainActor (Int?) -> Void)?
    /// Called when the server may hold a new Pro state (bought, renewed,
    /// refunded, restored). `AppState` re-reads `/api/v1/credits`.
    @ObservationIgnored var onPlanChanged: (@MainActor () -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var unfinishedTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "ResumeBuilder", category: "StoreKit")

    /// Loads the two packs and Pro, in sale order. Retired packs are never
    /// requested, so they cannot be sold even while App Store Connect has them.
    func loadProducts() async throws {
        let loaded = try await Product.products(for: ResumelyProducts.orderedIDs)
        products = loaded
            .filter {
                ResumelyProducts.exports(for: $0.id) != nil
                    ? $0.type == .consumable
                    : ResumelyProducts.isSubscription($0.id) && $0.type == .autoRenewable
            }
            .sorted {
                (ResumelyProducts.orderedIDs.firstIndex(of: $0.id) ?? .max)
                    < (ResumelyProducts.orderedIDs.firstIndex(of: $1.id) ?? .max)
            }
        if products.isEmpty { throw StoreKitManagerError.productUnavailable }
    }

    func purchase(_ product: Product, account: PurchaseAccount) async throws -> StoreKitPurchaseResult {
        let result = try await product.purchase(options: [.appAccountToken(account.userId)])
        switch result {
        case .success(.verified(let transaction)):
            let decision = await PurchaseDelivery.deliver(
                signedTransaction: result.jwsRepresentation ?? "",
                productID: transaction.productID,
                account: account,
                verifier: verifier,
                refreshAccount: { [weak self] in await self?.accountProvider?(true) },
                finish: { await transaction.finish() }
            )
            switch decision {
            case .finish(let verification):
                if verification.entitlement != nil { onPlanChanged?() }
                return .granted(verification)
            case .finishRevoked:
                throw StoreKitManagerError.purchaseRefunded
            case .otherAccount:
                throw StoreKitManagerError.ownedByAnotherAccount
            case .keep(let reason):
                // Paid, not granted. Retry in this session too, not only at the
                // next launch, and the sheet delivers it before selling again.
                Self.logger.error("purchase paid but not granted yet: \(reason, privacy: .public)")
                setPendingLock(userId: account.userId, productID: transaction.productID)
                scheduleRetries()
                throw StoreKitManagerError.grantPending
            }
        case .success(.unverified):
            throw StoreKitManagerError.unverifiedTransaction
        case .userCancelled:
            return .cancelled
        case .pending:
            setPendingLock(userId: account.userId, productID: product.id)
            return .pending
        @unknown default:
            throw StoreKitManagerError.purchaseFailed
        }
    }

    /// Subscribe to updates immediately, independently of slow unfinished
    /// verification. Replays and updates are idempotent on the server.
    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.deliverInBackground(result)
            }
        }
        unfinishedTask = Task { [weak self] in
            _ = await self?.deliverPendingPurchases()
            await self?.refreshEntitlements()
        }
    }

    /// Re-sends unfinished transactions and the current Pro plan, for example
    /// right after sign-in.
    func retryUnfinishedTransactions() async {
        _ = await deliverPendingPurchases()
        await refreshEntitlements()
    }

    /// What `refreshEntitlements()` found for the signed-in account.
    enum EntitlementRefresh: Equatable {
        /// Guest or anonymous session: nothing was sent.
        case noAccount
        /// This Apple ID has no current Pro transaction.
        case noPlan
        /// The server recorded this account's plan.
        case recorded(SubscriptionEntitlement)
        /// The plan belongs to another Resumely account.
        case ownedByAnotherAccount
        /// Offline or a server error; tried again at the next launch or sign-in.
        case failed
    }

    /// Sends the Pro transactions Apple holds as current to the server, at
    /// launch and after sign-in, so a purchase or renewal the server missed
    /// (notifications late, app killed, offline) still reaches it. Replays are
    /// safe: the server orders by Apple's signed dates (S1).
    @discardableResult
    func refreshEntitlements() async -> EntitlementRefresh {
        guard let account = await accountProvider?(false) else { return .noAccount }
        var outcome = EntitlementRefresh.noPlan
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ResumelyProducts.isSubscription(transaction.productID) else { continue }
            let decision = await PurchaseDelivery.deliver(
                signedTransaction: result.jwsRepresentation,
                productID: transaction.productID,
                account: account,
                verifier: verifier,
                refreshAccount: { [weak self] in await self?.accountProvider?(true) },
                finish: { await transaction.finish() }
            )
            switch decision {
            case .finish(let verification):
                if let entitlement = verification.entitlement { outcome = .recorded(entitlement) }
                // A plan recovered here (its first delivery failed) resumes a
                // paywall that is waiting for it (Codex on #226).
                await publishBackgroundGrant(verification, for: account.userId)
            case .otherAccount:
                if case .recorded = outcome { break }
                outcome = .ownedByAnotherAccount
            case .keep:
                // A plan already recorded in this pass stays the answer.
                if case .recorded = outcome { break }
                outcome = .failed
            case .finishRevoked:
                break
            }
        }
        if case .recorded = outcome { onPlanChanged?() }
        return outcome
    }

    /// Restore (App Store review 3.1.1): asks Apple for this Apple ID's
    /// purchases, then delivers unfinished packs and the current Pro plan.
    /// Packs live on the Resumely account, so signing in brings them back;
    /// only an unfinished pack or Pro needs Apple. Throws when the user cancels
    /// the Apple sign-in.
    func restorePurchases() async throws -> RestoreResult {
        try await AppStore.sync()
        let pack = await deliverPendingPurchases()
        return RestoreResult(deliveredGrant: pack != nil, plan: await refreshEntitlements())
    }

    struct RestoreResult: Equatable {
        /// An unfinished pack or Pro purchase was granted.
        let deliveredGrant: Bool
        let plan: EntitlementRefresh

        /// True when the export the user tapped can now go ahead.
        var unlocksExport: Bool {
            if deliveredGrant { return true }
            if case .recorded(let entitlement) = plan { return entitlement.active }
            return false
        }
    }

    /// Delivers every unfinished pack or Pro transaction and returns the first
    /// grant, if any. The paywall calls this before it sells a pack, so a user
    /// whose earlier grant failed gets those credits instead of paying twice.
    @discardableResult
    func deliverPendingPurchases() async -> PurchaseVerification? {
        var firstGrant: PurchaseVerification?
        for await result in Transaction.unfinished {
            // A Pro transaction the server says is no longer active (expired,
            // refunded) unlocks nothing, so it is not a grant for the paywall.
            if let granted = await deliverInBackground(result), firstGrant == nil,
               granted.entitlement?.active != false {
                firstGrant = granted
            }
        }
        return firstGrant
    }

    /// After a paid-but-not-granted purchase: try again in 5, 20 and 60 seconds.
    private func scheduleRetries() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            for delay in [5, 20, 60] {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                if await self.deliverPendingPurchases() != nil { return }
            }
        }
    }

    /// Verification can suspend while the user switches accounts. Publish only
    /// to the account that was verified, after checking the current session.
    @discardableResult
    func publishBackgroundGrant(_ verification: PurchaseVerification, for userId: UUID) async -> Bool {
        guard let current = await accountProvider?(false), current.userId == userId else { return false }
        onCreditsGranted?(verification.balance)
        // Resumes a waiting paywall, except for a Pro plan that is not active.
        if verification.entitlement?.active != false { backgroundGrantCount += 1 }
        return true
    }

    @discardableResult
    private func deliverInBackground(_ result: VerificationResult<Transaction>) async -> PurchaseVerification? {
        guard case .verified(let transaction) = result,
              ResumelyProducts.isDeliverable(transaction.productID) else {
            // Unverified, or a product this app never sold: never grant.
            return nil
        }
        let account = await accountProvider?(false)
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: result.jwsRepresentation,
            productID: transaction.productID,
            account: account,
            verifier: verifier,
            refreshAccount: { [weak self] in await self?.accountProvider?(true) },
            finish: { await transaction.finish() }
        )
        recordDelivery(decision, buyer: transaction.appAccountToken, productID: transaction.productID)
        if ResumelyProducts.isSubscription(transaction.productID) {
            switch decision {
            case .finish, .finishRevoked:
                // A renewal, a refund or an Ask to Buy approval of Pro.
                onPlanChanged?()
            case .keep, .otherAccount:
                break
            }
        }
        guard case .finish(let verification) = decision, let account,
              await publishBackgroundGrant(verification, for: account.userId) else { return nil }
        if verification.status == "granted" {
            // Ask to Buy approvals and retries land here, not in the sheet.
            AnalyticsService.shared.track(.purchaseCompleted(
                productId: transaction.productID,
                price: transaction.price.map { "\($0)" } ?? "",
                currency: transaction.currency?.identifier ?? "",
                creditsGranted: verification.creditsGranted
            ))
        }
        return verification
    }
}

private extension Product.PurchaseResult {
    var jwsRepresentation: String? {
        if case .success(let verification) = self { return verification.jwsRepresentation }
        return nil
    }
}
