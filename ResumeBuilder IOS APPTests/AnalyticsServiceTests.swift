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
    }

    // MARK: PII guard — all 11 events

    func testEventPropertiesExcludeForbiddenKeys() async {
        let events: [AnalyticsEvent] = [
            .appLaunched(isAuthenticated: true),
            .guestModeStarted,
            .resumeUploaded,
            .jobAdded(hasURL: true, hasPaste: false),
            .freeATSCompleted(scoreBucket: "61-80"),
            .signInCompleted,
            .optimizationStarted,
            .optimizationCompleted,
            .exportStarted,
            .exportSuccess,
            .exportFailed(errorCode: "unauthorized"),
        ]
        for event in events {
            for key in event.properties.keys {
                XCTAssertFalse(
                    AnalyticsService.forbiddenPropertyKeys.contains(key.lowercased()),
                    "Forbidden key \(key) in \(event.name)"
                )
            }
        }
    }

    // MARK: Event names

    func testAllEventNamesAreNonEmpty() async {
        let events: [AnalyticsEvent] = [
            .appLaunched(isAuthenticated: false), .guestModeStarted, .resumeUploaded,
            .jobAdded(hasURL: false, hasPaste: true), .freeATSCompleted(scoreBucket: "0-40"),
            .signInCompleted, .optimizationStarted, .optimizationCompleted,
            .exportStarted, .exportSuccess, .exportFailed(errorCode: "unknown"),
        ]
        for event in events {
            XCTAssertFalse(event.name.isEmpty, "Event name must not be empty")
        }
    }

    // MARK: Service enabled state

    func testServiceIsEnabledWhenTransportIsProvided() async {
        let service = AnalyticsService(transport: SpyTransport())
        XCTAssertTrue(service.isEnabled)
        service.track(.resumeUploaded) // must not crash
    }

    // MARK: Score buckets

    func testScoreBucketRanges() async {
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 30), "0-40")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 55), "41-60")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 72), "61-80")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 90), "81-100")
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
}
