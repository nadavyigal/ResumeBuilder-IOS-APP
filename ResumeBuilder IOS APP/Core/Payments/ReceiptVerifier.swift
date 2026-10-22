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
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    var baseURL: URL = BackendConfig.apiBaseURL
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    func verify(signedTransaction: String, productId: String, token: String) async throws -> PurchaseVerification {
        var request = URLRequest(url: baseURL.appendingPathComponent(Endpoint.iapVerify.path), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ResumelyClientHeader.value, forHTTPHeaderField: ResumelyClientHeader.name)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "signedTransaction": signedTransaction,
            "productId": productId,
        ])

        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else {
            throw ReceiptVerifierError.notGranted(status: 0, code: "invalid_response")
        }
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
