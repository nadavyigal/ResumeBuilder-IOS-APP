import Foundation
import OSLog

/// Tells the server a request comes from this app. The export-credit gate applies
/// only to iOS requests while web exports stay free (StoreKit spec 6.5, F1).
enum ResumelyClientHeader {
    static let name = "X-Resumely-Client"
    static let value = "ios"
}

/// Why the server refused an export (StoreKit spec 6.4).
enum ExportCreditsError: Error, Equatable, LocalizedError {
    /// 402 `export_credits_required`: no credit left. The paywall sheet opens.
    case creditsRequired
    /// 401 `account_required`: an anonymous session tried a charged export.
    case accountRequired

    var errorDescription: String? {
        switch self {
        case .creditsRequired:
            return NSLocalizedString("You need an export credit to download this résumé.", comment: "Export refused for lack of a credit")
        case .accountRequired:
            return NSLocalizedString("Create a free account to export your résumé.", comment: "Export refused for an anonymous session")
        }
    }
}

/// `POST /api/v1/exports/unlock`. Every export button calls this before any file
/// is made, so a local exporter never runs for an export the server refused.
/// One credit unlocks one optimization forever: a repeat answers `already_unlocked`
/// and spends nothing. With the server switch off it answers `ungated` and spends
/// nothing; the server alone decides, so the kill switch needs no app build.
struct ExportUnlockService: Sendable {
    struct Response: Decodable, Equatable, Sendable {
        let status: String
        let balance: Int?
    }

    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    private static let logger = Logger(subsystem: "ResumeBuilder", category: "ExportCredits")

    func unlock(optimizationId: String, token: String) async throws -> Response {
        let http = try await apiClient.postJSONResponse(
            endpoint: .exportsUnlock,
            body: ["optimizationId": optimizationId],
            token: token
        )
        let data = http.data
        let errorCode = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String

        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(Response.self, from: data)
        case 402:
            throw ExportCreditsError.creditsRequired
        case 401 where errorCode == "account_required":
            // Not a stale token: refreshing would not help, so this is not .unauthorized.
            throw ExportCreditsError.accountRequired
        case 401:
            throw APIClientError.unauthorized
        default:
            Self.logger.error("export unlock failed status=\(http.statusCode) error=\(errorCode ?? "none", privacy: .public)")
            throw APIClientError.serverError(status: http.statusCode, message: NSLocalizedString("We couldn't prepare your export. Please try again.", comment: "Export unlock failed"))
        }
    }
}

extension AppState {
    /// Asks the server for permission to export `optimizationId`, spending a credit
    /// only when the server's gate applies. Guests with no session skip it: the
    /// server cannot identify them, so it has nothing to charge, and their export
    /// path is the local copy of what is already on screen (spec section 3, E6).
    ///
    /// `beganSignedIn`: the export started with a session. If that session is gone
    /// now (a rejected token refresh signs out), this is not a guest export: stop
    /// instead of skipping the unlock (Codex P1 on #214).
    @MainActor
    func authorizeExport(
        optimizationId: String,
        beganSignedIn: Bool = false,
        service: ExportUnlockService = ExportUnlockService()
    ) async throws {
        guard session != nil else {
            if beganSignedIn { throw APIClientError.unauthorized }
            return
        }
        let response = try await callWithFreshToken { token in
            try await service.unlock(optimizationId: optimizationId, token: token)
        }
        if let balance = response.balance {
            creditsBalance = balance
        }
    }
}

extension AppState {
    /// The signed-in real account, or nil for guests and anonymous sessions, who
    /// cannot buy: the server would answer `account_required`.
    @MainActor
    var purchaseAccount: PurchaseAccount? {
        PurchaseAccount(session: session)
    }

    /// Starts delivering unfinished and new StoreKit transactions to the server
    /// (spec 7.1 step 4). Called once the session is restored at launch.
    @MainActor
    func startStoreKitObservation(_ store: StoreKitManager = .shared) {
        store.accountProvider = { [weak self] refresh in
            guard let self else { return nil }
            if refresh { _ = await self.refreshAccessToken() }
            return self.purchaseAccount
        }
        store.onCreditsGranted = { [weak self] balance in
            if let balance { self?.creditsBalance = balance }
        }
        store.startObservingTransactions()
    }
}

extension PurchaseAccount {
    /// Nil for no session, an anonymous session, or a user id that is not a UUID.
    init?(session: AuthSession?) {
        guard let session, session.isAccountSession, let userId = UUID(uuidString: session.userId) else { return nil }
        self.init(userId: userId, token: session.accessToken)
    }
}
