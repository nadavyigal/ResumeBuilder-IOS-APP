// Stage 2 — parked. Wired only when BackendConfig.isMonetizationEnabled is true.
import Foundation

struct ReceiptVerifier {
    private let apiClient = RuntimeServices.sharedAPIClient
    private let allowedProductIDs: Set<String> = ["credits_basic", "credits_saver", "credits_super"]

    func verifyPurchase(productID: String, transactionID: String, token: String) async throws {
        let trimmedProduct = productID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTransaction = transactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty, !trimmedTransaction.isEmpty else {
            throw ReceiptVerifierError.invalidPayload
        }
        guard allowedProductIDs.contains(trimmedProduct) else {
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
            return "Missing purchase details."
        case .invalidProductID:
            return "Unknown product."
        }
    }
}
