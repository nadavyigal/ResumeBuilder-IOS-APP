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
        finish: () async -> Void
    ) async -> Decision {
        guard let account else { return .keep(reason: "no_account") }
        let decision: Decision
        do {
            let verification = try await verifier.verify(
                signedTransaction: signedTransaction,
                productId: productID,
                token: account.token
            )
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
    @ObservationIgnored var accountProvider: (@MainActor () async -> PurchaseAccount?)?
    /// Called after a background delivery grants credits (new balance).
    @ObservationIgnored var onCreditsGranted: (@MainActor (Int?) -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
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
                finish: { await transaction.finish() }
            )
            switch decision {
            case .finish(let verification):
                return .granted(verification)
            case .finishRevoked:
                throw StoreKitManagerError.purchaseFailed
            case .keep(let reason):
                Self.logger.error("purchase paid but not granted yet: \(reason, privacy: .public)")
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
        for await result in Transaction.unfinished {
            await deliverInBackground(result)
        }
    }

    private func deliverInBackground(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              ExportCreditProducts.credits(for: transaction.productID) != nil else {
            // Unverified, or a product this app no longer sells: never grant.
            return
        }
        let account = await accountProvider?()
        let decision = await PurchaseDelivery.deliver(
            signedTransaction: result.jwsRepresentation,
            productID: transaction.productID,
            account: account,
            verifier: verifier,
            finish: { await transaction.finish() }
        )
        if case .finish(let verification) = decision {
            onCreditsGranted?(verification.balance)
        }
    }
}

private extension Product.PurchaseResult {
    var jwsRepresentation: String? {
        if case .success(let verification) = self { return verification.jwsRepresentation }
        return nil
    }
}
