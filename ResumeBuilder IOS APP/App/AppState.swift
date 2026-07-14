import Foundation
import Observation

struct ExportCompletionRecord: Codable, Sendable, Equatable {
    let optimizationId: String
    let exportedAt: Date
}

struct SavedResumeLinkRecord: Codable, Sendable, Equatable {
    let optimizationId: String
    let resume: SavedResume
    let savedAt: Date
}

struct SubmitPackageCachedScreeningAnswer: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let question: String
    let answer: String
    let evidenceUsed: [String]
    let confidenceNote: String?
}

struct SubmitPackageCacheRecord: Codable, Sendable, Equatable {
    let optimizationId: String
    let sourceURLString: String?
    let coverLetterText: String?
    let screeningAnswers: [SubmitPackageCachedScreeningAnswer]
    let savedAt: Date
}

enum OptimizationRecoveryState: Sendable, Equatable {
    case idle
    case loading
    case ready
    case recovered
    case empty
    case failed
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
    private(set) var latestOptimization: OptimizationHistoryItem?
    private(set) var optimizationRecoveryState: OptimizationRecoveryState = .idle
    private var optimizationJobURLs: [String: String] = [:]
    private var submitPackageRecords: [String: SubmitPackageCacheRecord] = [:]
    private var savedResumeRecords: [String: SavedResumeLinkRecord] = [:]
    private var latestOptimizationStorage: String?

    /// Real, in-session signals for the locked-tab teaser checklists (Optimized/Design/Expert).
    /// Not persisted across launches — only tracks progress made in the current session,
    /// since there is no durable pre-optimization resume/job state yet.
    var hasUploadedResumeThisSession = false
    var hasAddedJobThisSession = false

    nonisolated static let latestOptimizationKey = "latest_optimization_id"
    nonisolated static let exportCompletionKey = "last_export_completion"
    nonisolated static let anonymousConversionPendingKey = "anonymous_conversion_pending"
    nonisolated static let optimizationJobURLsKey = "optimization_job_urls"
    nonisolated static let submitPackageRecordsKey = "submit_package_records"
    nonisolated static let savedResumeRecordsKey = "saved_resume_records"

    var latestOptimizationId: String? {
        get { latestOptimizationStorage }
        set {
            let normalized = Self.normalizedOptimizationId(newValue)
            let didChange = latestOptimizationStorage != normalized
            latestOptimizationStorage = normalized
            if didChange, latestOptimization?.id != normalized {
                latestOptimization = nil
            }
            if let normalized {
                UserDefaults.standard.set(normalized, forKey: Self.latestOptimizationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.latestOptimizationKey)
            }
        }
    }

    let apiClient = RuntimeServices.sharedAPIClient
    private let optimizationHistoryService: any OptimizationHistoryServiceProtocol
    private let anonymousSessionKey = "anonymous_ats_session_id"
    private var refreshTask: Task<String, Error>?

    init(
        optimizationHistoryService: any OptimizationHistoryServiceProtocol = OptimizationHistoryService()
    ) {
        self.optimizationHistoryService = optimizationHistoryService
    }

    var isAuthenticated: Bool {
        session != nil
    }

    func bootstrap() {
        session = AuthService.shared.restoreSession()
        if let session {
            AnalyticsService.shared.prepareRestoredSession(userId: session.userId, email: session.email)
        }
        anonymousATSSessionId = UserDefaults.standard.string(forKey: anonymousSessionKey)
        latestOptimizationId = UserDefaults.standard.string(forKey: Self.latestOptimizationKey)
        exportCompletion = Self.loadExportCompletion()
        optimizationJobURLs = Self.loadOptimizationJobURLs()
        submitPackageRecords = Self.loadSubmitPackageRecords()
        savedResumeRecords = Self.loadSavedResumeRecords()
    }

    func bootstrapAndRefreshSession() async {
        bootstrap()
        await refreshSessionIfNeeded()
        if UserDefaults.standard.bool(forKey: Self.anonymousConversionPendingKey) {
            await convertAnonymousSessionIfNeeded()
        }
        await reconcileLatestOptimization()
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
        latestOptimization = nil
        optimizationRecoveryState = .idle
        exportCompletion = nil
        optimizationJobURLs = [:]
        submitPackageRecords = [:]
        savedResumeRecords = [:]
        UserDefaults.standard.removeObject(forKey: Self.exportCompletionKey)
        UserDefaults.standard.removeObject(forKey: Self.optimizationJobURLsKey)
        UserDefaults.standard.removeObject(forKey: Self.submitPackageRecordsKey)
        UserDefaults.standard.removeObject(forKey: Self.savedResumeRecordsKey)
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

    func rememberSavedResume(_ resume: SavedResume, for optimizationId: String) {
        guard !optimizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        savedResumeRecords[optimizationId] = SavedResumeLinkRecord(
            optimizationId: optimizationId,
            resume: resume,
            savedAt: Date()
        )
        if let data = try? JSONEncoder().encode(savedResumeRecords) {
            UserDefaults.standard.set(data, forKey: Self.savedResumeRecordsKey)
        }
    }

    func savedResumeRecord(for optimizationId: String?) -> SavedResumeLinkRecord? {
        guard let optimizationId else { return nil }
        return savedResumeRecords[optimizationId]
    }

    func rememberJobURL(_ urlString: String?, for optimizationId: String) {
        let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !optimizationId.isEmpty, !trimmed.isEmpty else { return }
        optimizationJobURLs[optimizationId] = trimmed
        if let data = try? JSONEncoder().encode(optimizationJobURLs) {
            UserDefaults.standard.set(data, forKey: Self.optimizationJobURLsKey)
        }
    }

    func jobURL(for optimizationId: String?) -> String? {
        guard let optimizationId else { return nil }
        return optimizationJobURLs[optimizationId]
    }

    func rememberSubmitPackage(
        for optimizationId: String,
        sourceURLString: String?,
        coverLetterText: String?,
        screeningAnswers: [SubmitPackageCachedScreeningAnswer]
    ) {
        guard !optimizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmedSourceURL = sourceURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCoverLetter = coverLetterText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = SubmitPackageCacheRecord(
            optimizationId: optimizationId,
            sourceURLString: trimmedSourceURL?.isEmpty == false ? trimmedSourceURL : nil,
            coverLetterText: trimmedCoverLetter?.isEmpty == false ? trimmedCoverLetter : nil,
            screeningAnswers: screeningAnswers,
            savedAt: Date()
        )
        submitPackageRecords[optimizationId] = record
        if let sourceURLString = record.sourceURLString {
            rememberJobURL(sourceURLString, for: optimizationId)
        }
        if let data = try? JSONEncoder().encode(submitPackageRecords) {
            UserDefaults.standard.set(data, forKey: Self.submitPackageRecordsKey)
        }
    }

    func submitPackageRecord(for optimizationId: String?) -> SubmitPackageCacheRecord? {
        guard let optimizationId else { return nil }
        return submitPackageRecords[optimizationId]
    }

    private static func loadExportCompletion() -> ExportCompletionRecord? {
        guard let data = UserDefaults.standard.data(forKey: exportCompletionKey) else { return nil }
        return try? JSONDecoder().decode(ExportCompletionRecord.self, from: data)
    }

    private static func loadOptimizationJobURLs() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: optimizationJobURLsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private static func loadSubmitPackageRecords() -> [String: SubmitPackageCacheRecord] {
        guard let data = UserDefaults.standard.data(forKey: submitPackageRecordsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: SubmitPackageCacheRecord].self, from: data)) ?? [:]
    }

    private static func loadSavedResumeRecords() -> [String: SavedResumeLinkRecord] {
        guard let data = UserDefaults.standard.data(forKey: savedResumeRecordsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: SavedResumeLinkRecord].self, from: data)) ?? [:]
    }

    func setSession(_ session: AuthSession) async {
        self.session = session
        AnalyticsService.shared.identifyAuthenticatedUser(userId: session.userId, email: session.email)
        AnalyticsService.shared.track(.signInCompleted)
        await convertAnonymousSessionIfNeeded()
        await refreshCredits()
        await reconcileLatestOptimization()
    }

    func reconcileLatestOptimization() async {
        guard isAuthenticated else {
            latestOptimization = nil
            optimizationRecoveryState = .idle
            return
        }
        guard optimizationRecoveryState != .loading else { return }
        if let latestOptimizationId,
           latestOptimization?.id == latestOptimizationId,
           optimizationRecoveryState == .ready || optimizationRecoveryState == .recovered {
            return
        }

        let localOptimizationId = latestOptimizationId
        optimizationRecoveryState = .loading
        latestOptimizationId = nil
        latestOptimization = nil

        do {
            let history = try await callWithFreshToken { token in
                try await self.optimizationHistoryService.list(token: token)
            }
            let completed = history.filter(Self.isRecoverableOptimization)

            if let localOptimizationId,
               let localItem = completed.first(where: { $0.id == localOptimizationId }) {
                latestOptimizationId = localItem.id
                latestOptimization = localItem
                optimizationRecoveryState = .ready
                return
            }

            guard let recovered = completed.max(by: { $0.createdAt < $1.createdAt }) else {
                latestOptimizationId = nil
                latestOptimization = nil
                optimizationRecoveryState = .empty
                return
            }

            latestOptimizationId = recovered.id
            latestOptimization = recovered
            optimizationRecoveryState = .recovered
            AnalyticsService.shared.track(.optimizationStateRecovered(optimizationId: recovered.id))
        } catch {
            latestOptimization = nil
            optimizationRecoveryState = .failed
        }
    }

    func dismissOptimizationRecoveryNotice() {
        guard optimizationRecoveryState == .recovered else { return }
        optimizationRecoveryState = .ready
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
        if error is URLError {
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

    private nonisolated static func normalizedOptimizationId(_ id: String?) -> String? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.lowercased().hasPrefix("mock-") else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func isRecoverableOptimization(_ item: OptimizationHistoryItem) -> Bool {
        guard normalizedOptimizationId(item.id) == item.id else { return false }
        return item.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "completed"
    }
}
