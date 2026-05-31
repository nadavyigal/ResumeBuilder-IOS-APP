import Foundation
import Observation

struct ExportCompletionRecord: Codable, Sendable, Equatable {
    let optimizationId: String
    let exportedAt: Date
}

@Observable
@MainActor
final class AppState {
    var session: AuthSession?
    var pendingSharedJobURL: URL?
    var anonymousATSSessionId: String?
    var creditsBalance: Int = 0
    var resumeSectionsNeedRefresh: Bool = false
    var resumePreviewRefreshToken: Int = 0
    var hasBootstrappedSession = false
    var exportCompletion: ExportCompletionRecord?

    nonisolated static let latestOptimizationKey = "latest_optimization_id"
    nonisolated static let exportCompletionKey = "last_export_completion"

    var latestOptimizationId: String? {
        didSet {
            if let latestOptimizationId {
                UserDefaults.standard.set(latestOptimizationId, forKey: Self.latestOptimizationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.latestOptimizationKey)
            }
        }
    }

    let apiClient = APIClient()
    private let anonymousSessionKey = "anonymous_ats_session_id"

    var isAuthenticated: Bool {
        session != nil
    }

    func bootstrap() {
        session = AuthService.shared.restoreSession()
        anonymousATSSessionId = UserDefaults.standard.string(forKey: anonymousSessionKey)
        let storedOptimizationId = UserDefaults.standard.string(forKey: Self.latestOptimizationKey)
        if storedOptimizationId?.hasPrefix("mock-") == true {
            UserDefaults.standard.removeObject(forKey: Self.latestOptimizationKey)
            latestOptimizationId = nil
        } else {
            latestOptimizationId = storedOptimizationId
        }
        exportCompletion = Self.loadExportCompletion()
    }

    func bootstrapAndRefreshSession() async {
        bootstrap()
        await refreshSessionIfNeeded()
        hasBootstrappedSession = true
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
        latestOptimizationId = nil
        exportCompletion = nil
        UserDefaults.standard.removeObject(forKey: Self.exportCompletionKey)
    }

    func markExportComplete(for optimizationId: String) {
        let record = ExportCompletionRecord(optimizationId: optimizationId, exportedAt: Date())
        exportCompletion = record
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: Self.exportCompletionKey)
        }
    }

    func isExportComplete(for optimizationId: String?) -> Bool {
        guard let optimizationId, let exportCompletion else { return false }
        return exportCompletion.optimizationId == optimizationId
    }

    nonisolated private static func loadExportCompletion() -> ExportCompletionRecord? {
        guard let data = UserDefaults.standard.data(forKey: exportCompletionKey) else { return nil }
        return try? JSONDecoder().decode(ExportCompletionRecord.self, from: data)
    }

    func setSession(_ session: AuthSession) async {
        self.session = session
        AnalyticsService.shared.setDistinctId(session.userId)
        AnalyticsService.shared.track(.signInCompleted)
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

    @discardableResult
    func refreshAccessToken() async -> String? {
        guard let refreshToken = session?.refreshToken else {
            signOut()
            return nil
        }

        do {
            let newSession = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
            session = newSession
            return newSession.accessToken
        } catch {
            signOut()
            return nil
        }
    }

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
