import Foundation

/// The server's answer to `POST /api/v1/iap/verify` (StoreKit spec 7.2).
struct PurchaseVerification: Decodable, Equatable, Sendable {
    /// `granted`, or `already_granted` for a repeat of the same transaction.
    let status: String
    let creditsGranted: Int
    let balance: Int?
    /// Set for Pro only: the plan the server recorded (pricing v2, S1).
    let entitlement: SubscriptionEntitlement?

    init(status: String, creditsGranted: Int, balance: Int?, entitlement: SubscriptionEntitlement? = nil) {
        self.status = status
        self.creditsGranted = creditsGranted
        self.balance = balance
        self.entitlement = entitlement
    }
}

/// The Pro plan as the server sees it. The server decides every export; the app
/// only shows this (Profile, paywall).
struct SubscriptionEntitlement: Decodable, Equatable, Sendable {
    let active: Bool
    let productId: String?
    /// ISO 8601 from the server, for example `2026-11-29T10:00:00+00:00`.
    let expiresAt: String?

    var expiryDate: Date? { ServerDate.parse(expiresAt) }
}

/// Postgres and `toISOString()` write timestamps with or without fractions.
enum ServerDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: value) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }
}

enum ReceiptVerifierError: Error, Equatable {
    /// 409 `transaction_revoked`: Apple refunded it. It will never grant, so the
    /// app finishes it instead of re-sending it at every launch.
    case revoked
    /// Pro bought under another Resumely account (409
    /// `subscription_owned_by_another_account`, or 403 `account_mismatch` for
    /// Pro). The transaction stays unfinished so that account still gets it.
    case ownedByAnotherAccount
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
        if (http.statusCode == 409 && code == "subscription_owned_by_another_account")
            || (http.statusCode == 403 && code == "account_mismatch" && ResumelyProducts.isSubscription(productId)) {
            throw ReceiptVerifierError.ownedByAnotherAccount
        }
        throw ReceiptVerifierError.notGranted(status: http.statusCode, code: code)
    }
}
