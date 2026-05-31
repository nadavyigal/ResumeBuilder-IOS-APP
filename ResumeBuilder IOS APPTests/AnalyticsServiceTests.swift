import XCTest
@testable import ResumeBuilder_IOS_APP

final class AnalyticsServiceTests: XCTestCase {
    func testBuildCapturePayloadShape() {
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

    func testEventPropertiesExcludeForbiddenKeys() {
        let events: [AnalyticsEvent] = [
            .appLaunched(isAuthenticated: true),
            .jobAdded(hasURL: true, hasPaste: false),
            .freeATSCompleted(scoreBucket: "61-80"),
            .exportFailed(errorCode: "unauthorized"),
        ]
        for event in events {
            for key in event.properties.keys {
                XCTAssertFalse(
                    AnalyticsService.forbiddenPropertyKeys.contains(key.lowercased()),
                    "Forbidden key \\(key) in \\(event.name)"
                )
            }
        }
    }

    func testDisabledAnalyticsDoesNotRequireTransport() {
        let service = AnalyticsService(transport: nil)
        XCTAssertFalse(service.isEnabled)
        service.track(.resumeUploaded)
    }

    func testScoreBucketRanges() {
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 30), "0-40")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 55), "41-60")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 72), "61-80")
        XCTAssertEqual(AnalyticsEvent.scoreBucket(for: 90), "81-100")
    }
}
