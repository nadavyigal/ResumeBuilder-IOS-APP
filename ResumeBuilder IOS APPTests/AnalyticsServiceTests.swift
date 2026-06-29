import XCTest
@testable import ResumeBuilder_IOS_APP

// MARK: - Spy transport

/// Records captured event names in order. @unchecked Sendable is safe here
/// because all access happens on the MainActor during tests.
private final class SpyTransport: AnalyticsTransport, @unchecked Sendable {
    var captured: [String] = []
    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        captured.append(event)
    }
}

// MARK: - Tests

// Every test must be async — @MainActor on the class requires it so XCTest
// uses the Swift Concurrency dispatch path rather than the ObjC runtime path,
// which would bypass actor isolation and crash @Observable access.
@MainActor
final class AnalyticsServiceTests: XCTestCase {

    // MARK: Payload shape

    func testBuildCapturePayloadShape() async {
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
        XCTAssertEqual(props?["app"], "resumely")
        XCTAssertFalse((props?["app_version"] ?? "").isEmpty)
        XCTAssertFalse((props?["build_number"] ?? "").isEmpty)
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
            "export_started",
            "export_success",
            "export_failed",
            "diagnosis_viewed",
            "ats_improve_tapped",
            "export_pdf_tapped",
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
            [:],
            [:],
            [:],
            [:],
            ["error_code": "unauthorized"],
            ["match_score": "72"],
            ["current_score": "55"],
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
        .optimizationStarted,
        .optimizationCompleted,
        .exportStarted,
        .exportSuccess,
        .exportFailed(errorCode: "unauthorized"),
        .diagnosisViewed(matchScore: 72),
        .atsImproveTapped(currentScore: 55),
        .exportPdfTapped,
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
    ]
}
