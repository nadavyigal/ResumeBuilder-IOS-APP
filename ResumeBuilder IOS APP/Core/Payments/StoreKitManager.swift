// Stage 2 — parked. Wired only when BackendConfig.isMonetizationEnabled is true.
// TODO(Stage2-RES-IAP): sandbox QA + flip isMonetizationEnabled after backend verify ships.
import Foundation
import Observation
import StoreKit

enum StoreKitProductCatalog: Sendable {
    static let availableProductIDs: Set<String> = ["credits_basic", "credits_saver", "credits_super"]
}

@Observable
@MainActor
final class StoreKitManager {
    var availableProductIDs: [String] = Array(StoreKitProductCatalog.availableProductIDs).sorted()
    private(set) var products: [Product] = []

    func loadProducts() async {
        do {
            products = try await Product.products(for: availableProductIDs)
        } catch {
            products = []
        }
    }

    func purchase(productID: String) async throws -> String {
        guard availableProductIDs.contains(productID) else {
            throw StoreKitManagerError.invalidProductID
        }
        guard let product = products.first(where: { $0.id == productID }) else {
            let loaded = try await Product.products(for: [productID])
            guard let product = loaded.first else {
                throw StoreKitManagerError.productUnavailable
            }
            return try await purchase(product: product)
        }
        return try await purchase(product: product)
    }

    private func purchase(product: Product) async throws -> String {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return String(transaction.id)
            case .unverified:
                throw StoreKitManagerError.unverifiedTransaction
            }
        case .userCancelled:
            throw StoreKitManagerError.userCancelled
        case .pending:
            throw StoreKitManagerError.pending
        @unknown default:
            throw StoreKitManagerError.purchaseFailed
        }
    }
}

enum StoreKitManagerError: LocalizedError {
    case invalidProductID
    case productUnavailable
    case unverifiedTransaction
    case userCancelled
    case pending
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .invalidProductID:
            return "Unknown product."
        case .productUnavailable:
            return "Product is not available."
        case .unverifiedTransaction:
            return "Purchase could not be verified."
        case .userCancelled:
            return "Purchase cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .purchaseFailed:
            return "Purchase failed."
        }
    }
}
