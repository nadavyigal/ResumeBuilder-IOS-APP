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

    // MARK: - Token refresh

    /// Refreshes the Supabase access token using the stored refresh token.
    /// Updates `session` in place and returns the new access token, or nil if refresh fails.
    @discardableResult
    func refreshAccessToken() async -> String? {
        guard let refreshToken = session?.refreshToken else {
            session = nil
            return nil
        }
        do {
            let newSession = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
            session = newSession
            return newSession.accessToken
        } catch {
            // Refresh token itself expired — force re-login
            session = nil
            return nil
        }
    }

    /// Returns a valid access token, refreshing automatically on 401.
    /// Pass the closure that makes the authenticated API call; on unauthorized it
    /// refreshes once and retries before propagating the error.
    func callWithFreshToken<T>(_ work: (String) async throws -> T) async throws -> T {
        guard let token = session?.accessToken else {
            throw APIClientError.unauthorized
        }
        do {
            return try await work(token)
        } catch APIClientError.unauthorized {
            guard let freshToken = await refreshAccessToken() else {
                throw APIClientError.unauthorized
            }
            return try await work(freshToken)
        }
    }
}
