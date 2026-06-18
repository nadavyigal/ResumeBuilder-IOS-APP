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
    var applicationsRefreshToken: Int = 0
    var hasBootstrappedSession = false
    var exportCompletion: ExportCompletionRecord?

    nonisolated static let latestOptimizationKey = "latest_optimization_id"
    nonisolated static let exportCompletionKey = "last_export_completion"
    nonisolated static let anonymousConversionPendingKey = "anonymous_conversion_pending"

    var latestOptimizationId: String? {
        didSet {
            if let latestOptimizationId {
                UserDefaults.standard.set(latestOptimizationId, forKey: Self.latestOptimizationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.latestOptimizationKey)
            }
        }
    }

    let apiClient = RuntimeServices.sharedAPIClient
    private let anonymousSessionKey = "anonymous_ats_session_id"
    private var refreshTask: Task<String, Error>?

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
        if UserDefaults.standard.bool(forKey: Self.anonymousConversionPendingKey) {
            await convertAnonymousSessionIfNeeded()
        }
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
        refreshTask?.cancel()
        refreshTask = nil
        AnalyticsService.shared.resetDistinctId()
    }

    /// Deletes the account server-side, then clears all local state.
    func deleteAccount() async throws {
        try await callWithFreshToken { token in
            try await AuthService.shared.deleteAccount(accessToken: token)
        }
        AnalyticsService.shared.track(.accountDeleted)
        signOut()
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

    private static func loadExportCompletion() -> ExportCompletionRecord? {
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
            UserDefaults.standard.set(false, forKey: Self.anonymousConversionPendingKey)
        } catch {
            UserDefaults.standard.set(true, forKey: Self.anonymousConversionPendingKey)
        }
    }

    func refreshSessionIfNeeded() async {
        guard let currentSession = session,
              let refreshToken = currentSession.refreshToken else { return }

        guard JWTDecoder.shouldRefresh(accessToken: currentSession.accessToken) else { return }

        do {
            let newSession = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
            session = newSession
        } catch {
            if shouldSignOutAfterRefreshFailure(error) {
                signOut()
            }
        }
    }

    @discardableResult
    func refreshAccessToken() async -> String? {
        if let existing = refreshTask {
            return try? await existing.value
        }

        guard let refreshToken = session?.refreshToken else {
            signOut()
            return nil
        }

        let task = Task<String, Error> { @MainActor in
            do {
                let newSession = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
                self.session = newSession
                return newSession.accessToken
            } catch {
                if self.shouldSignOutAfterRefreshFailure(error) {
                    self.signOut()
                }
                throw error
            }
        }
        refreshTask = task
        defer { refreshTask = nil }

        return try? await task.value
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

    private func shouldSignOutAfterRefreshFailure(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return false
        }
        if let authError = error as? AuthServiceError {
            if case .invalidResponse = authError { return true }
            return authError.isAuthFailure
        }
        if case AuthServiceError.serverError(let message) = error {
            let lower = message.lowercased()
            return lower.contains("401") || lower.contains("unauthorized")
        }
        return false
    }
}
