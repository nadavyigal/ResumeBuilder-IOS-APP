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
    private let anonymousSessionKey = "anonymous_ats_session_id"

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
        guard let token = session?.accessToken,
              let sessionId = anonymousATSSessionId else { return }
        do {
            let _: APIStatusResponse = try await apiClient.postJSON(
                endpoint: .convertAnonymousSession,
                body: ["sessionId": sessionId],
                token: token
            )
            anonymousATSSessionId = nil
            UserDefaults.standard.removeObject(forKey: anonymousSessionKey)
        } catch {
            // Keep the anonymous ID so conversion can be retried later.
        }
    }

    func refreshSessionIfNeeded() async {
        guard let refreshToken = session?.refreshToken else { return }
        do {
            let newSession = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
            session = newSession
        } catch {
            signOut()
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
