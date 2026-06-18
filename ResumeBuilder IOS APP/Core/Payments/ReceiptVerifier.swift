// Stage 2 — parked. Wired only when BackendConfig.isMonetizationEnabled is true.
import Foundation

struct ReceiptVerifier {
    private let apiClient = RuntimeServices.sharedAPIClient

    func verifyPurchase(productID: String, transactionID: String, token: String) async throws {
        let trimmedProduct = productID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTransaction = transactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty, !trimmedTransaction.isEmpty else {
            throw ReceiptVerifierError.invalidPayload
        }
        guard StoreKitProductCatalog.availableProductIDs.contains(trimmedProduct) else {
            throw ReceiptVerifierError.invalidProductID
        }

        let _: IAPVerifyResponse = try await apiClient.postJSON(
            endpoint: .iapVerify,
            body: [
                "productId": trimmedProduct,
                "appleTransactionId": trimmedTransaction,
            ],
            token: token
        )
    }
}

enum ReceiptVerifierError: LocalizedError {
    case invalidPayload
    case invalidProductID

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return NSLocalizedString("Missing purchase details.", comment: "")
        case .invalidProductID:
            return NSLocalizedString("Unknown product.", comment: "")
        }
    }
}
