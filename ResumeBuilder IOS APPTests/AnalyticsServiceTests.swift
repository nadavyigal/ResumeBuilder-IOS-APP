import XCTest
@testable import ResumeBuilder_IOS_APP

// MARK: - Spy transport

/// Records captured event names in order. @unchecked Sendable is safe here
/// because all access happens on the MainActor during tests.
private final class SpyTransport: AnalyticsTransport, @unchecked Sendable {
    var captured: [String] = []
    var capturedProperties: [[String: String]] = []
    var capturedDistinctIds: [String] = []
    var aliases: [(previousDistinctId: String, userDistinctId: String, properties: [String: String])] = []
    var identifies: [(distinctId: String, userProperties: [String: String])] = []

    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        captured.append(event)
        capturedProperties.append(properties)
        capturedDistinctIds.append(distinctId)
    }

    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {
        aliases.append((previousDistinctId, userDistinctId, properties))
    }

    func identify(distinctId: String, userProperties: [String: String]) async throws {
        identifies.append((distinctId, userProperties))
    }
}

// MARK: - Tests

// Every test must be async — @MainActor on the class requires it so XCTest
// uses the Swift Concurrency dispatch path rather than the ObjC runtime path,
// which would bypass actor isolation and crash @Observable access.
@MainActor
final class AnalyticsServiceTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        resetAnalyticsDefaults()
    }

    override func tearDown() async throws {
        resetAnalyticsDefaults()
        try await super.tearDown()
    }

    // MARK: Payload shape

    func testBuildCapturePayloadShape() async {
        UserDefaults.standard.set("anon-123", forKey: AnalyticsService.anonymousSessionIdKey)
        let payload = AnalyticsService.buildCapturePayload(
            apiKey: "phc_test",
            event: .appLaunched(isAuthenticated: false),
            distinctId: "anon-123"
        )
        XCTAssertEqual(payload["api_key"] as? String, "phc_test")
        XCTAssertEqual(payload["event"] as? String, "app_launched")
        XCTAssertEqual(payload["distinct_id"] as? String, "anon-123")
        let props = payload["properties"] as? [String: String]
        XCTAssertEqual(props?["is_authenticated"], "false")
        XCTAssertEqual(props?["$lib"], "resumely-ios-urlsession")
        XCTAssertEqual(props?["platform"], "ios")
        XCTAssertEqual(props?["$os"], "iOS")
        XCTAssertEqual(props?["app"], "resumely_ios")
        XCTAssertFalse((props?["app_version"] ?? "").isEmpty)
        XCTAssertFalse((props?["marketing_version"] ?? "").isEmpty)
        XCTAssertFalse((props?["build_number"] ?? "").isEmpty)
        XCTAssertEqual(props?["anonymous_session_id"], "anon-123")
        XCTAssertEqual(props?["is_internal_tester"], "true")
    }

    func testBuildAliasPayloadShape() async {
        UserDefaults.standard.set("anon-before-auth", forKey: AnalyticsService.anonymousSessionIdKey)
        let payload = AnalyticsService.buildAliasPayload(
            apiKey: "phc_test",
            previousDistinctId: "anon-before-auth",
            userDistinctId: "user-123"
        )
        XCTAssertEqual(payload["event"] as? String, "$create_alias")
        XCTAssertEqual(payload["distinct_id"] as? String, "anon-before-auth")
        let props = payload["properties"] as? [String: String]
        XCTAssertEqual(props?["alias"], "user-123")
        XCTAssertEqual(props?["anonymous_session_id"], "anon-before-auth")
        XCTAssertEqual(props?["app"], "resumely_ios")
    }

    func testBuildIdentifyPayloadShape() async {
        UserDefaults.standard.set("anon-before-auth", forKey: AnalyticsService.anonymousSessionIdKey)
        let payload = AnalyticsService.buildIdentifyPayload(
            apiKey: "phc_test",
            distinctId: "user-123",
            isInternalTester: true
        )
        XCTAssertEqual(payload["event"] as? String, "$identify")
        XCTAssertEqual(payload["distinct_id"] as? String, "user-123")
        let props = payload["properties"] as? [String: [String: String]]
        XCTAssertEqual(props?["$set"]?["is_internal_tester"], "true")
        XCTAssertEqual(props?["$set"]?["anonymous_session_id"], "anon-before-auth")
        XCTAssertEqual(props?["$set"]?["app"], "resumely_ios")
    }

    // MARK: PII guard — all events

    func testEventPropertiesExcludeForbiddenKeys() async {
        for event in Self.allAnalyticsEvents {
            for key in event.properties.keys {
                XCTAssertFalse(
                    AnalyticsService.forbiddenPropertyKeys.contains(key.lowercased()),
                    "Forbidden key \(key) in \(event.name)"
                )
            }
        }
    }

    // MARK: Event names

    func testAllEventNamesMatchPostHogContract() async {
        let expectedNames = [
            "app_launched",
            "guest_mode_started",
            "resume_uploaded",
            "job_added",
            "free_ats_completed",
            "sign_in_completed",
            "account_deleted",
            "optimization_started",
            "optimization_completed",
            "optimization_state_recovered",
            "optimized_viewed",
            "export_started",
            "export_success",
            "export_failed",
            "diagnosis_viewed",
            "ats_improve_tapped",
            "export_pdf_tapped",
            "export_cta_seen",
            "submit_package_saved",
            "fit_check_started",
            "fit_check_completed",
            "fit_check_optimize_tapped",
            "fit_check_skipped",
            "resume_upload_cta_tapped",
            "resume_file_picker_opened",
            "resume_file_picker_cancelled",
            "resume_file_selected",
            "resume_upload_preflight_rejected",
            "resume_upload_started",
            "resume_upload_failed",
            "resume_upload_succeeded",
            "resume_upload_error_shown",
            "resume_upload_sheet_dismissed",
            "resume_upload_coming_soon_tapped",
            "resume_upload_cta_seen",
        ]
        XCTAssertEqual(Self.allAnalyticsEvents.map(\.name), expectedNames)
    }

    func testAllEventPropertiesMatchPostHogContract() async {
        let expectedProperties: [[String: String]] = [
            ["is_authenticated": "true"],
            [:],
            ["file_type": "pdf"],
            ["has_url": "true", "has_paste": "false"],
            ["score_bucket": "61-80"],
            [:],
            [:],
            ["resume_id": "resume-1", "job_description_id": "job-1"],
            ["optimization_id": "opt-1", "review_id": "review-1"],
            ["optimization_id": "opt-1"],
            [:],
            [:],
            [:],
            ["error_code": "unauthorized"],
            ["match_score": "72"],
            ["current_score": "55"],
            [:],
            [:],
            ["has_cover_letter": "true"],
            [:],
            ["verdict": "stretch", "match_score": "68"],
            [:],
            [:],
            ["source": "home"],
            ["source": "home"],
            ["source": "home"],
            ["file_type": "pdf", "file_size_bucket": "100kb-1mb"],
            ["reason": "unreadable"],
            ["file_type": "pdf"],
            ["failure_stage": "upload", "error_code": "500"],
            ["file_type": "pdf"],
            ["error_code": "500"],
            ["source": "home"],
            ["route": "scan"],
            ["source": "home"],
        ]
        XCTAssertEqual(Self.allAnalyticsEvents.map(\.properties), expectedProperties)
    }

    // MARK: Service enabled state

    func testServiceIsEnabledWhenTransportIsProvided() async {
        let service = AnalyticsService(transport: SpyTransport())
        XCTAssertTrue(service.isEnabled)
        service.track(.resumeUploaded(fileType: "pdf")) // must not crash
    }

    // MARK: Score buckets

    func testScoreBucketRanges() async {
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 30), "0-40")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 55), "41-60")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 72), "61-80")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 90), "81-100")
    }

    func testResetDistinctIdClearsStoredID() async {
        let key = AnalyticsService.distinctIdKey
        UserDefaults.standard.set("user-123", forKey: key)
        let service = AnalyticsService(transport: SpyTransport())
        service.resetDistinctId()
        XCTAssertNil(UserDefaults.standard.string(forKey: key))
        _ = service.isEnabled
    }

    func testAnonymousSessionIdPersistsAndDistinctIdSwitchesAfterIdentify() async throws {
        UserDefaults.standard.set("anon-before-auth", forKey: AnalyticsService.anonymousSessionIdKey)
        let spy = SpyTransport()
        let service = AnalyticsService(transport: spy)

        service.track(.appLaunched(isAuthenticated: false))
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(spy.capturedDistinctIds.last, "anon-before-auth")
        XCTAssertEqual(spy.capturedProperties.last?["anonymous_session_id"], "anon-before-auth")

        service.identifyAuthenticatedUser(userId: "user-123", email: nil)
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(spy.aliases.first?.previousDistinctId, "anon-before-auth")
        XCTAssertEqual(spy.aliases.first?.userDistinctId, "user-123")
        XCTAssertEqual(spy.identifies.first?.distinctId, "user-123")
        XCTAssertEqual(spy.identifies.first?.userProperties["is_internal_tester"], "true")

        service.track(.signInCompleted)
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(spy.capturedDistinctIds.last, "user-123")
        XCTAssertEqual(spy.capturedProperties.last?["anonymous_session_id"], "anon-before-auth")
    }

    // MARK: Export action analytics

    /// export_started fires first, then export_failed when the AppState has no token.
    func testExportActionTracksStartedThenFailedWhenUnauthenticated() async throws {
        let spy = SpyTransport()
        let analytics = AnalyticsService(transport: spy)
        let viewModel = OptimizedResumeViewModel(optimizationId: "test-opt-001")
        let appState = AppState()          // no session → callWithFreshToken throws .unauthorized

        do {
            _ = try await ResumeExportAction.exportPDF(
                viewModel: viewModel,
                appState: appState,
                analytics: analytics
            )
            XCTFail("Expected exportPDF to throw when unauthenticated")
        } catch {}

        // Allow the analytics Task spawned inside track() to drain on the main actor.
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(spy.captured, ["export_started", "export_failed"],
                       "export_started must precede export_failed")
    }

    /// No events fire at all when the viewModel has no optimization ID.
    func testExportActionFiresNoEventsWhenOptimizationIdIsNil() async throws {
        let spy = SpyTransport()
        let analytics = AnalyticsService(transport: spy)
        let viewModel = OptimizedResumeViewModel(optimizationId: nil)
        let appState = AppState()

        do {
            _ = try await ResumeExportAction.exportPDF(
                viewModel: viewModel,
                appState: appState,
                analytics: analytics
            )
            XCTFail("Expected throw")
        } catch {}

        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(spy.captured.isEmpty,
                      "No analytics events should fire when optimizationId is nil (guard throws before track)")
    }

    private static let allAnalyticsEvents: [AnalyticsEvent] = [
        .appLaunched(isAuthenticated: true),
        .guestModeStarted,
        .resumeUploaded(fileType: "pdf"),
        .jobAdded(hasURL: true, hasPaste: false),
        .freeATSCompleted(scoreBucket: "61-80"),
        .signInCompleted,
        .accountDeleted,
        .optimizationStarted(resumeId: "resume-1", jobDescriptionId: "job-1"),
        .optimizationCompleted(optimizationId: "opt-1", reviewId: "review-1"),
        .optimizationStateRecovered(optimizationId: "opt-1"),
        .optimizedViewed,
        .exportStarted,
        .exportSuccess,
        .exportFailed(errorCode: "unauthorized"),
        .diagnosisViewed(matchScore: 72),
        .atsImproveTapped(currentScore: 55),
        .exportPdfTapped,
        .exportCTASeen,
        .submitPackageSaved(hasCoverLetter: true),
        .fitCheckStarted,
        .fitCheckCompleted(verdict: "stretch", matchScore: 68),
        .fitCheckOptimizeTapped,
        .fitCheckSkipped,
        .resumeUploadCTATapped(source: "home"),
        .resumeFilePickerOpened(source: "home"),
        .resumeFilePickerCancelled(source: "home"),
        .resumeFileSelected(fileType: "pdf", sizeBucket: "100kb-1mb"),
        .resumeUploadPreflightRejected(reason: "unreadable"),
        .resumeUploadStarted(fileType: "pdf"),
        .resumeUploadFailed(failureStage: "upload", errorCode: "500"),
        .resumeUploadSucceeded(fileType: "pdf"),
        .resumeUploadErrorShown(errorCode: "500"),
        .resumeUploadSheetDismissed(source: "home"),
        .resumeUploadComingSoonTapped(route: "scan"),
        .resumeUploadCTASeen(source: "home"),
    ]

    private func resetAnalyticsDefaults() {
        UserDefaults.standard.removeObject(forKey: AnalyticsService.distinctIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.anonymousSessionIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.authenticatedUserIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.internalTesterKey)
    }
}
