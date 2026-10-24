import Foundation

/// The server's answer to `POST /api/v1/iap/verify` (StoreKit spec 7.2).
struct PurchaseVerification: Decodable, Equatable, Sendable {
    /// `granted`, or `already_granted` for a repeat of the same transaction.
    let status: String
    let creditsGranted: Int
    let balance: Int?
}

enum ReceiptVerifierError: Error, Equatable {
    /// 409 `transaction_revoked`: Apple refunded it. It will never grant, so the
    /// app finishes it instead of re-sending it at every launch.
    case revoked
    /// Any other refusal or failure. The transaction stays unfinished and is
    /// re-sent at the next launch or `Transaction.updates` (spec 7.1 step 4).
    case notGranted(status: Int, code: String)
}

protocol PurchaseVerifying: Sendable {
    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification
}

/// Sends the StoreKit 2 `jwsRepresentation` to the server. The server checks
/// Apple's signature and grants the credits; the app never sends an amount.
struct ReceiptVerifier: PurchaseVerifying {
    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        let http = try await apiClient.postJSONResponse(
            endpoint: .iapVerify,
            body: ["signedTransaction": signedTransaction, "productId": productId],
            token: token,
            timeout: 60
        )
        let data = http.data
        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(PurchaseVerification.self, from: data)
        }
        let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "unknown"
        if http.statusCode == 409, code == "transaction_revoked" {
            throw ReceiptVerifierError.revoked
        }
        throw ReceiptVerifierError.notGranted(status: http.statusCode, code: code)
    }
}
