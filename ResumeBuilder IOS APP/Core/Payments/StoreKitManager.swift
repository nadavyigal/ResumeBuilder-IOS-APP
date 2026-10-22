import Foundation
import Observation
import OSLog
import StoreKit

/// The three consumable packs (StoreKit spec section 4, F4). Prices live in App
/// Store Connect only: the app shows `product.displayPrice`, never a typed price.
enum ExportCreditProducts {
    /// Display order: 1, 5, 10.
    static let orderedIDs = ["resumely.exports.1", "resumely.exports.5", "resumely.exports.10"]

    static func credits(for productID: String) -> Int? {
        switch productID {
        case "resumely.exports.1": return 1
        case "resumely.exports.5": return 5
        case "resumely.exports.10": return 10
        default: return nil
        }
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
        } catch ReceiptVerifierError.notGranted(let status, let code) {
            decision = .keep(reason: status == 0 ? code : "\(status)_\(code)")
        } catch {
            decision = .keep(reason: "network")
        }
        switch decision {
        case .finish, .finishRevoked:
            await finish()
        case .keep:
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

    var errorDescription: String? {
        switch self {
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

/// StoreKit 2 for export credits (StoreKit spec 7.1 and 10.1). The server decides
/// when the paywall shows (a 402); this class only loads products, buys, and
/// delivers transactions to the server.
@Observable
@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()

    private(set) var products: [Product] = []
    var verifier: PurchaseVerifying = ReceiptVerifier()

    /// Set by `AppState` at launch: the account a delivery is made for, or nil
    /// when no real account is signed in (guests and anonymous sessions).
    /// `refresh: true` refreshes the access token first.
    @ObservationIgnored var accountProvider: (@MainActor (_ refresh: Bool) async -> PurchaseAccount?)?
    /// Called after a background delivery grants credits (new balance).
    @ObservationIgnored var onCreditsGranted: (@MainActor (Int?) -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "ResumeBuilder", category: "StoreKit")

    func loadProducts() async throws {
        let loaded = try await Product.products(for: ExportCreditProducts.orderedIDs)
        products = loaded
            .filter { ExportCreditProducts.credits(for: $0.id) != nil && $0.type == .consumable }
            .sorted {
                (ExportCreditProducts.orderedIDs.firstIndex(of: $0.id) ?? .max)
                    < (ExportCreditProducts.orderedIDs.firstIndex(of: $1.id) ?? .max)
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
                return .granted(verification)
            case .finishRevoked:
                throw StoreKitManagerError.purchaseRefunded
            case .keep(let reason):
                // Paid, not granted. Retry in this session too, not only at the
                // next launch, and the sheet delivers it before selling again.
                Self.logger.error("purchase paid but not granted yet: \(reason, privacy: .public)")
                scheduleRetries()
                throw StoreKitManagerError.grantPending
            }
        case .success(.unverified):
            throw StoreKitManagerError.unverifiedTransaction
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            throw StoreKitManagerError.purchaseFailed
        }
    }

    /// Delivers every unfinished transaction now, then every new one as it
    /// arrives (spec 7.1 step 4). Safe to repeat: the server grants a
    /// transaction ID once, ever.
    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.unfinished {
                await self?.deliverInBackground(result)
            }
            for await result in Transaction.updates {
                await self?.deliverInBackground(result)
            }
        }
    }

    /// Re-sends unfinished transactions, for example right after sign-in.
    func retryUnfinishedTransactions() async {
        _ = await deliverPendingPurchases()
    }

    /// Delivers every unfinished export-credit transaction and returns the first
    /// grant, if any. The paywall calls this before it sells a pack, so a user
    /// whose earlier grant failed gets those credits instead of paying twice.
    @discardableResult
    func deliverPendingPurchases() async -> PurchaseVerification? {
        var firstGrant: PurchaseVerification?
        for await result in Transaction.unfinished {
            if let granted = await deliverInBackground(result), firstGrant == nil {
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

    @discardableResult
    private func deliverInBackground(_ result: VerificationResult<Transaction>) async -> PurchaseVerification? {
        guard case .verified(let transaction) = result,
              ExportCreditProducts.credits(for: transaction.productID) != nil else {
            // Unverified, or a product this app no longer sells: never grant.
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
        guard case .finish(let verification) = decision else { return nil }
        onCreditsGranted?(verification.balance)
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
