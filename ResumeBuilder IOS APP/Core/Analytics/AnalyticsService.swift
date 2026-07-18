import Foundation

protocol AnalyticsTransport: Sendable {
    func capture(event: String, properties: [String: String], distinctId: String) async throws
    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws
    func identify(distinctId: String, userProperties: [String: String]) async throws
}

struct PostHogAnalyticsTransport: AnalyticsTransport, Sendable {
    private let apiKey: String
    private let host: URL
    private let session: URLSession

    init(apiKey: String, host: URL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.host = host
        self.session = session
    }

    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        try await post(event: event, distinctId: distinctId, properties: properties.mapValues { $0 as Any })
    }

    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {
        try await post(
            event: "$create_alias",
            distinctId: previousDistinctId,
            properties: properties
                .merging(["alias": userDistinctId]) { current, _ in current }
                .mapValues { $0 as Any }
        )
    }

    func identify(distinctId: String, userProperties: [String: String]) async throws {
        try await post(
            event: "$identify",
            distinctId: distinctId,
            properties: ["$set": userProperties as Any]
        )
    }

    private func post(event: String, distinctId: String, properties: [String: Any]) async throws {
        var request = URLRequest(url: host.appendingPathComponent("capture"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "distinct_id": distinctId,
            "properties": properties,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AnalyticsError.transportFailed
        }
    }
}

enum AnalyticsError: Error, Equatable {
    case transportFailed
    case disabled
}

enum AnalyticsFlowVersion: String, Sendable {
    case fitGateV1 = "fit_gate_v1"
    case directOptimizeV2 = "direct_optimize_v2"

    static func current(isFitCheckEnabled: Bool) -> Self {
        isFitCheckEnabled ? .fitGateV1 : .directOptimizeV2
    }
}

enum AnalyticsEvent: Sendable {
    case appLaunched(isAuthenticated: Bool)
    case guestModeStarted
    case resumeUploaded(fileType: String)
    case jobAdded(hasURL: Bool, hasPaste: Bool)
    case analysisCTATapped(source: String, flowVersion: AnalyticsFlowVersion, hasURL: Bool, hasPaste: Bool)
    case jobInputValidationShown(surface: String, reason: String)
    case freeATSCompleted(scoreBucket: String)
    case signInCompleted
    case accountDeleted
    case optimizationStarted(resumeId: String?, jobDescriptionId: String?)
    case optimizationCompleted(optimizationId: String?, reviewId: String?)
    case optimizationStateRecovered(optimizationId: String)
    case optimizationStateRecoveryFailed(errorCode: String)
    case optimizationApplyStarted(reviewId: String, approvedGroupCount: Int)
    case optimizationApplySucceeded(optimizationId: String, reviewId: String)
    case optimizationApplyFailed(reviewId: String, errorCode: String)
    case optimizedViewed(optimizationId: String)
    case optimizedPreviewRendered(optimizationId: String)
    case savedResumePromptViewed(optimizationId: String)
    case saveStarted(optimizationId: String)
    case saveSuccess(optimizationId: String)
    case saveFailed(optimizationId: String, errorCode: String)
    case exportStarted(optimizationId: String)
    case exportSuccess(optimizationId: String)
    case exportFailed(optimizationId: String, errorCode: String)
    case diagnosisViewed(matchScore: Int)
    case recommendationViewed(surface: String, safetyState: String, reviewId: String?, itemId: String?)
    case recommendationIncluded(surface: String, safetyState: String, evidenceState: String, reviewId: String?, itemId: String?)
    case recommendationEdited(surface: String, safetyState: String, reviewId: String?, itemId: String?)
    case recommendationSkipped(surface: String, safetyState: String, evidenceState: String, reviewId: String?, itemId: String?)
    case recommendationBlocked(surface: String, reason: String, reviewId: String?, itemId: String?)
    /// Counts only — quote content never leaves the device.
    case recommendationEvidenceShown(surface: String, jobQuoteCount: Int, resumeQuoteCount: Int, reviewId: String?, itemId: String?)
    case atsImproveTapped(currentScore: Int)
    case exportPdfTapped(optimizationId: String)
    case exportCTASeen(optimizationId: String)
    case submitPackageSaved(hasCoverLetter: Bool)
    // Fit-First Triage (WP-12)
    case fitCheckStarted
    case fitCheckCompleted(verdict: String, matchScore: Int)
    case fitCheckOptimizeTapped
    case fitCheckSkipped
    // Upload / import journey (WP-18)
    case resumeUploadCTATapped(source: String)
    case resumeFilePickerOpened(source: String)
    case resumeFilePickerCancelled(source: String)
    case resumeFileSelected(fileType: String, sizeBucket: String)
    case resumeUploadPreflightRejected(reason: String)
    case resumeUploadStarted(fileType: String)
    case resumeUploadFailed(failureStage: String, errorCode: String)
    case resumeUploadSucceeded(fileType: String)
    case resumeUploadErrorShown(errorCode: String)
    case resumeUploadSheetDismissed(source: String)
    case resumeUploadComingSoonTapped(route: String)
    case resumeUploadCTASeen(source: String)

    nonisolated var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .guestModeStarted: return "guest_mode_started"
        case .resumeUploaded: return "resume_uploaded"
        case .jobAdded: return "job_added"
        case .analysisCTATapped: return "analysis_cta_tapped"
        case .jobInputValidationShown: return "job_input_validation_shown"
        case .freeATSCompleted: return "free_ats_completed"
        case .signInCompleted: return "sign_in_completed"
        case .accountDeleted: return "account_deleted"
        case .optimizationStarted: return "optimization_started"
        case .optimizationCompleted: return "optimization_completed"
        case .optimizationStateRecovered: return "optimization_state_recovered"
        case .optimizationStateRecoveryFailed: return "optimization_state_recovery_failed"
        case .optimizationApplyStarted: return "optimization_apply_started"
        case .optimizationApplySucceeded: return "optimization_apply_succeeded"
        case .optimizationApplyFailed: return "optimization_apply_failed"
        case .optimizedViewed: return "optimized_viewed"
        case .optimizedPreviewRendered: return "optimized_preview_rendered"
        case .savedResumePromptViewed: return "saved_resume_prompt_viewed"
        case .saveStarted: return "save_started"
        case .saveSuccess: return "save_success"
        case .saveFailed: return "save_failed"
        case .exportStarted: return "export_started"
        case .exportSuccess: return "export_success"
        case .exportFailed: return "export_failed"
        case .diagnosisViewed: return "diagnosis_viewed"
        case .recommendationViewed: return "recommendation_viewed"
        case .recommendationIncluded: return "recommendation_included"
        case .recommendationEdited: return "recommendation_edited"
        case .recommendationSkipped: return "recommendation_skipped"
        case .recommendationBlocked: return "recommendation_blocked"
        case .recommendationEvidenceShown: return "recommendation_evidence_shown"
        case .atsImproveTapped: return "ats_improve_tapped"
        case .exportPdfTapped: return "export_pdf_tapped"
        case .exportCTASeen: return "export_cta_seen"
        case .submitPackageSaved: return "submit_package_saved"
        case .fitCheckStarted: return "fit_check_started"
        case .fitCheckCompleted: return "fit_check_completed"
        case .fitCheckOptimizeTapped: return "fit_check_optimize_tapped"
        case .fitCheckSkipped: return "fit_check_skipped"
        case .resumeUploadCTATapped: return "resume_upload_cta_tapped"
        case .resumeFilePickerOpened: return "resume_file_picker_opened"
        case .resumeFilePickerCancelled: return "resume_file_picker_cancelled"
        case .resumeFileSelected: return "resume_file_selected"
        case .resumeUploadPreflightRejected: return "resume_upload_preflight_rejected"
        case .resumeUploadStarted: return "resume_upload_started"
        case .resumeUploadFailed: return "resume_upload_failed"
        case .resumeUploadSucceeded: return "resume_upload_succeeded"
        case .resumeUploadErrorShown: return "resume_upload_error_shown"
        case .resumeUploadSheetDismissed: return "resume_upload_sheet_dismissed"
        case .resumeUploadComingSoonTapped: return "resume_upload_coming_soon_tapped"
        case .resumeUploadCTASeen: return "resume_upload_cta_seen"
        }
    }

    nonisolated var properties: [String: String] {
        switch self {
        case .appLaunched(let isAuthenticated):
            return ["is_authenticated": isAuthenticated ? "true" : "false"]
        case .guestModeStarted, .signInCompleted, .accountDeleted,
             .fitCheckOptimizeTapped, .fitCheckSkipped:
            return [:]
        case .optimizationStarted(let resumeId, let jobDescriptionId):
            return Self.compactProperties([
                "resume_id": resumeId,
                "job_description_id": jobDescriptionId,
            ])
        case .optimizationCompleted(let optimizationId, let reviewId):
            return Self.compactProperties([
                "optimization_id": optimizationId,
                "review_id": reviewId,
            ])
        case .optimizationStateRecovered(let optimizationId):
            return ["optimization_id": optimizationId]
        case .optimizationStateRecoveryFailed(let errorCode):
            return ["error_code": errorCode]
        case .optimizationApplyStarted(let reviewId, let approvedGroupCount):
            return ["review_id": reviewId, "approved_group_count": "\(approvedGroupCount)"]
        case .optimizationApplySucceeded(let optimizationId, let reviewId):
            return ["optimization_id": optimizationId, "review_id": reviewId]
        case .optimizationApplyFailed(let reviewId, let errorCode):
            return ["review_id": reviewId, "error_code": errorCode]
        case .optimizedViewed(let optimizationId),
             .optimizedPreviewRendered(let optimizationId),
             .savedResumePromptViewed(let optimizationId),
             .saveStarted(let optimizationId),
             .saveSuccess(let optimizationId),
             .exportStarted(let optimizationId),
             .exportSuccess(let optimizationId),
             .exportPdfTapped(let optimizationId),
             .exportCTASeen(let optimizationId):
            return ["optimization_id": optimizationId]
        case .resumeUploaded(let fileType):
            return ["file_type": fileType]
        case .jobAdded(let hasURL, let hasPaste):
            return [
                "has_url": hasURL ? "true" : "false",
                "has_paste": hasPaste ? "true" : "false",
            ]
        case .analysisCTATapped(let source, let flowVersion, let hasURL, let hasPaste):
            return [
                "source": source,
                "flow_version": flowVersion.rawValue,
                "job_input_source": Self.jobInputSource(hasURL: hasURL, hasPaste: hasPaste),
                "extraction_quality": "unknown",
                "requirement_count_bucket": "unknown",
                "score_version": "ats_v2_legacy",
            ]
        case .jobInputValidationShown(let surface, let reason):
            return ["surface": surface, "reason": reason]
        case .freeATSCompleted(let scoreBucket):
            return ["score_bucket": scoreBucket]
        case .exportFailed(let optimizationId, let errorCode),
             .saveFailed(let optimizationId, let errorCode):
            return ["optimization_id": optimizationId, "error_code": errorCode]
        case .diagnosisViewed(let matchScore):
            return ["match_score": "\(matchScore)"]
        case .recommendationViewed(let surface, let safetyState, let reviewId, let itemId),
             .recommendationEdited(let surface, let safetyState, let reviewId, let itemId):
            return Self.compactProperties([
                "surface": surface,
                "safety_state": safetyState,
                "review_id": reviewId,
                "item_id": itemId,
            ])
        case .recommendationIncluded(let surface, let safetyState, let evidenceState, let reviewId, let itemId),
             .recommendationSkipped(let surface, let safetyState, let evidenceState, let reviewId, let itemId):
            return Self.compactProperties([
                "surface": surface,
                "safety_state": safetyState,
                "evidence_state": evidenceState,
                "review_id": reviewId,
                "item_id": itemId,
            ])
        case .recommendationBlocked(let surface, let reason, let reviewId, let itemId):
            return Self.compactProperties([
                "surface": surface,
                "reason": reason,
                "review_id": reviewId,
                "item_id": itemId,
            ])
        case .recommendationEvidenceShown(let surface, let jobQuoteCount, let resumeQuoteCount, let reviewId, let itemId):
            return Self.compactProperties([
                "surface": surface,
                "job_quote_count": "\(jobQuoteCount)",
                "resume_quote_count": "\(resumeQuoteCount)",
                "review_id": reviewId,
                "item_id": itemId,
            ])
        case .atsImproveTapped(let currentScore):
            return ["current_score": "\(currentScore)"]
        case .submitPackageSaved(let hasCoverLetter):
            return ["has_cover_letter": hasCoverLetter ? "true" : "false"]
        case .fitCheckStarted:
            return [
                "flow_version": AnalyticsFlowVersion.fitGateV1.rawValue,
                "score_version": "ats_v2_legacy",
            ]
        case .fitCheckCompleted(let verdict, let matchScore):
            return [
                "verdict": verdict,
                "match_score": "\(matchScore)",
                "score_bucket": Self.scoreBucket(for: matchScore),
                "flow_version": AnalyticsFlowVersion.fitGateV1.rawValue,
                "score_version": "ats_v2_legacy",
            ]
        case .resumeUploadCTATapped(let source),
             .resumeUploadCTASeen(let source),
             .resumeFilePickerOpened(let source),
             .resumeFilePickerCancelled(let source):
            return ["source": source]
        case .resumeFileSelected(let fileType, let sizeBucket):
            return ["file_type": fileType, "file_size_bucket": sizeBucket]
        case .resumeUploadPreflightRejected(let reason):
            return ["reason": reason]
        case .resumeUploadStarted(let fileType), .resumeUploadSucceeded(let fileType):
            return ["file_type": fileType]
        case .resumeUploadFailed(let failureStage, let errorCode):
            return ["failure_stage": failureStage, "error_code": errorCode]
        case .resumeUploadErrorShown(let errorCode):
            return ["error_code": errorCode]
        case .resumeUploadSheetDismissed(let source):
            return ["source": source]
        case .resumeUploadComingSoonTapped(let route):
            return ["route": route]
        }
    }

    nonisolated static func scoreBucket(for score: Int) -> String {
        switch score {
        case ...40: return "0-40"
        case 41...60: return "41-60"
        case 61...80: return "61-80"
        default: return "81-100"
        }
    }

    nonisolated private static func jobInputSource(hasURL: Bool, hasPaste: Bool) -> String {
        switch (hasURL, hasPaste) {
        case (true, true): return "url_and_paste"
        case (true, false): return "url"
        case (false, true): return "paste"
        case (false, false): return "none"
        }
    }

    nonisolated private static func compactProperties(_ values: [String: String?]) -> [String: String] {
        values.compactMapValues { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }
    }
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let transport: (any AnalyticsTransport)?
    private let distinctIdProvider: () -> String
    nonisolated static let distinctIdKey = "analytics_distinct_id"
    nonisolated static let anonymousSessionIdKey = "analytics_anonymous_session_id"
    nonisolated static let authenticatedUserIdKey = "analytics_authenticated_user_id"
    nonisolated static let internalTesterKey = "analytics_is_internal_tester"

    init(
        transport: (any AnalyticsTransport)? = nil,
        distinctIdProvider: (() -> String)? = nil
    ) {
        if let transport {
            self.transport = transport
        } else if BackendConfig.isPostHogEnabled,
                  let key = BackendConfig.postHogAPIKey,
                  let host = BackendConfig.postHogHost {
            self.transport = PostHogAnalyticsTransport(apiKey: key, host: host)
        } else {
            self.transport = nil
        }
        self.distinctIdProvider = distinctIdProvider ?? {
            if let userId = UserDefaults.standard.string(forKey: AnalyticsService.authenticatedUserIdKey),
               !userId.isEmpty {
                return userId
            }
            return AnalyticsService.anonymousSessionId()
        }
    }

    var isEnabled: Bool { transport != nil }

    func setDistinctId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.authenticatedUserIdKey)
        UserDefaults.standard.set(id, forKey: Self.distinctIdKey)
    }

    /// Clears the stored distinct ID so the next track call creates a fresh anonymous ID.
    func resetDistinctId() {
        UserDefaults.standard.removeObject(forKey: Self.distinctIdKey)
        UserDefaults.standard.removeObject(forKey: Self.anonymousSessionIdKey)
        UserDefaults.standard.removeObject(forKey: Self.authenticatedUserIdKey)
        UserDefaults.standard.removeObject(forKey: Self.internalTesterKey)
    }

    func prepareRestoredSession(userId: String, email: String?) {
        UserDefaults.standard.set(userId, forKey: Self.authenticatedUserIdKey)
        UserDefaults.standard.set(userId, forKey: Self.distinctIdKey)
        UserDefaults.standard.set(Self.resolveInternalTester(userId: userId), forKey: Self.internalTesterKey)
    }

    func identifyAuthenticatedUser(userId: String, email: String?) {
        let anonymousId = Self.anonymousSessionId()
        let previousDistinctId = distinctIdProvider()
        let isInternalTester = Self.resolveInternalTester(userId: userId)
        UserDefaults.standard.set(userId, forKey: Self.authenticatedUserIdKey)
        UserDefaults.standard.set(userId, forKey: Self.distinctIdKey)
        UserDefaults.standard.set(isInternalTester, forKey: Self.internalTesterKey)

        guard let transport else { return }
        let userProperties = Self.identityProperties(isInternalTester: isInternalTester)
        Task {
            do {
                if previousDistinctId != userId {
                    try await transport.alias(
                        previousDistinctId: previousDistinctId.isEmpty ? anonymousId : previousDistinctId,
                        userDistinctId: userId,
                        properties: Self.baseProperties
                    )
                }
                try await transport.identify(distinctId: userId, userProperties: userProperties)
            } catch {
                #if DEBUG
                print("Analytics identity update failed: \(error)")
                #endif
            }
        }
    }

    func track(_ event: AnalyticsEvent) {
        guard let transport else { return }
        let distinctId = distinctIdProvider()
        let payload = event.properties.merging(Self.baseProperties) { current, _ in current }
        // Guard PII at the call site — fire in debug builds so new event cases
        // are caught during development before any key ever reaches the network.
        assert(
            Set(payload.keys).isDisjoint(with: Self.forbiddenPropertyKeys),
            "[Analytics] Event '\(event.name)' contains a forbidden property key. Remove PII before shipping."
        )
        #if DEBUG
        print("Analytics captured: \(event.name)")
        #endif
        Task {
            do {
                try await transport.capture(
                    event: event.name,
                    properties: payload,
                    distinctId: distinctId
                )
            } catch {
                // Analytics must never block user flows.
                #if DEBUG
                print("Analytics transport failed for \(event.name): \(error)")
                #endif
            }
        }
    }

    nonisolated static func buildCapturePayload(
        apiKey: String,
        event: AnalyticsEvent,
        distinctId: String
    ) -> [String: Any] {
        [
            "api_key": apiKey,
            "event": event.name,
            "distinct_id": distinctId,
            "properties": event.properties.merging(baseProperties) { current, _ in current },
        ]
    }

    nonisolated static func buildAliasPayload(
        apiKey: String,
        previousDistinctId: String,
        userDistinctId: String
    ) -> [String: Any] {
        [
            "api_key": apiKey,
            "event": "$create_alias",
            "distinct_id": previousDistinctId,
            "properties": baseProperties.merging(["alias": userDistinctId]) { current, _ in current },
        ]
    }

    nonisolated static func buildIdentifyPayload(
        apiKey: String,
        distinctId: String,
        isInternalTester: Bool
    ) -> [String: Any] {
        [
            "api_key": apiKey,
            "event": "$identify",
            "distinct_id": distinctId,
            "properties": [
                "$set": identityProperties(isInternalTester: isInternalTester),
            ],
        ]
    }

    nonisolated static var baseProperties: [String: String] {
        [
            "$lib": "resumely-ios-urlsession",
            "platform": "ios",
            "$os": "iOS",
            "app": "resumely_ios",
            "app_version": bundleString("CFBundleShortVersionString"),
            "marketing_version": bundleString("CFBundleShortVersionString"),
            "build_number": bundleString("CFBundleVersion"),
            "anonymous_session_id": anonymousSessionId(),
            "is_internal_tester": currentInternalTesterValue() ? "true" : "false",
        ]
    }

    nonisolated private static func identityProperties(isInternalTester: Bool) -> [String: String] {
        baseProperties.merging([
            "is_internal_tester": isInternalTester ? "true" : "false",
        ]) { _, new in new }
    }

    nonisolated private static func bundleString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unknown"
    }

    nonisolated static func anonymousSessionId() -> String {
        if let existing = UserDefaults.standard.string(forKey: anonymousSessionIdKey),
           !existing.isEmpty {
            return existing
        }
        if UserDefaults.standard.string(forKey: authenticatedUserIdKey) == nil,
           let legacyDistinctId = UserDefaults.standard.string(forKey: distinctIdKey),
           !legacyDistinctId.isEmpty {
            UserDefaults.standard.set(legacyDistinctId, forKey: anonymousSessionIdKey)
            return legacyDistinctId
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: anonymousSessionIdKey)
        return created
    }

    nonisolated static func resolveInternalTester(userId: String?) -> Bool {
        #if DEBUG
        return true
        #else
        if ProcessInfo.processInfo.arguments.contains("--internal-tester") {
            return true
        }
        if ProcessInfo.processInfo.environment["RESUMELY_INTERNAL_TESTER"] == "1" {
            return true
        }
        if isRunningFromTestFlight {
            return true
        }
        guard let userId, !userId.isEmpty else { return false }
        return configuredInternalTesterUserIds.contains(userId)
        #endif
    }

    nonisolated private static func currentInternalTesterValue() -> Bool {
        if resolveInternalTester(userId: UserDefaults.standard.string(forKey: authenticatedUserIdKey)) {
            return true
        }
        return UserDefaults.standard.bool(forKey: internalTesterKey)
    }

    nonisolated private static var isRunningFromTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    nonisolated private static var configuredInternalTesterUserIds: Set<String> {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "INTERNAL_TESTER_USER_IDS") as? String,
              !raw.contains("$(") else { return [] }
        return Set(
            raw.split { character in
                character == "," || character == "\n" || character == " "
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        )
    }

    nonisolated static let forbiddenPropertyKeys: Set<String> = [
        "email", "name", "resume", "job", "job_description", "resume_text", "file_name",
    ]
}
