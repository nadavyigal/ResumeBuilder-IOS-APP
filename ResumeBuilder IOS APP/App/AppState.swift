import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var session: AuthSession?
    var pendingSharedJobURL: URL?
    var anonymousATSSessionId: String?
    var creditsBalance: Int = 0

    let apiClient = APIClient()
    private let anonymousSessionKey = "resumebuilder.anonymousATS.sessionId"

    var isAuthenticated: Bool {
        session != nil
    }

    func bootstrap() {
        session = AuthService.shared.restoreSession()
        anonymousATSSessionId = UserDefaults.standard.string(forKey: anonymousSessionKey)
    }

    func handleIncomingURL(_ url: URL) {
        if let sharedURL = DeepLinkRouter.parseSharedJobURL(from: url) {
            pendingSharedJobURL = sharedURL
        }
    }

    func signOut() {
        AuthService.shared.clearSession()
        session = nil
        creditsBalance = 0
    }

    func setSession(_ session: AuthSession) async {
        self.session = session
        await convertAnonymousSessionIfNeeded()
        await refreshCredits()
    }

    func storeAnonymousATSSessionId(_ sessionId: String?) {
        guard let sessionId, !sessionId.isEmpty else { return }
        anonymousATSSessionId = sessionId
        UserDefaults.standard.set(sessionId, forKey: anonymousSessionKey)
    }

    func clearPendingSharedJobURL() {
        pendingSharedJobURL = nil
    }

    func identityDebugSummary() -> String {
        apiClient.supabaseIdentityDebugSummary(session: session)
    }

    func convertAnonymousSessionIfNeeded() async {
        guard let sessionId = anonymousATSSessionId, !sessionId.isEmpty else { return }
        guard let token = session?.accessToken else { return }

        struct ConvertSessionRequest: Encodable {
            let sessionId: String
        }

        do {
            let _: APIStatusResponse = try await apiClient.postCodable(
                endpoint: .convertAnonymousSession,
                body: ConvertSessionRequest(sessionId: sessionId),
                token: token
            )
        } catch {
            // Conversion is best-effort; the score still remains usable locally.
        }
    }

    func refreshCredits() async {
        guard BackendConfig.isMonetizationEnabled else { return }
        guard let token = session?.accessToken else { return }

        do {
            let response: CreditsResponse = try await apiClient.get(endpoint: .credits, token: token)
            creditsBalance = response.balance
        } catch {
            // Keep prior balance on transient failures.
        }
    }
}
