// ResumeBuilder IOS APP/Payments/StoreManager.swift
// Plan 3: StoreKit Paywall — product loading, purchase, transaction observer
//
// SKELETON — implement when gate opens (EXD-009):
//   1. CFO validates prices
//   2. D7 activation data readable in PostHog
//   3. Engineering spec written and approved
//
// Architecture:
//   - StoreKit 2 native API (iOS 15+)
//   - @MainActor @Observable class (not ObservableObject)
//   - Load products: Product.products(for: PurchaseTier.allCases.map(\.productID))
//   - Purchase: product.purchase()
//   - Observe: Transaction.updates async sequence
//   - On successful transaction: POST to supabase/functions/storekit-verify
//   - On restore: re-verify all unfinished transactions

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreManager {
    var products: [Product] = []
    var purchaseError: String?
    var isPurchasing: Bool = false

    @ObservationIgnored
    private nonisolated(unsafe) var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProducts() async {
        // TODO: Implement
        // products = try await Product.products(for: PurchaseTier.allCases.map(\.productID))
    }

    func purchase(_ tier: PurchaseTier) async {
        // TODO: Implement
        // guard let product = products.first(where: { $0.id == tier.productID }) else { return }
        // let result = try await product.purchase()
        // handle result: .success(verification), .userCancelled, .pending
    }

    func restorePurchases() async {
        // TODO: Implement
        // try await AppStore.sync()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await _ in Transaction.updates {
                // TODO: Implement
                // Verify transaction, call storekit-verify edge function, finish transaction
            }
        }
    }
}
