import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S5: the app half of the funnel contract (plan section 6). Names
// are snake_case, properties never carry CV text, emails or names.

private final class FunnelTransport: AnalyticsTransport, @unchecked Sendable {
    var events: [(name: String, properties: [String: String])] = []

    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        events.append((event, properties))
    }
    func alias(previousDistinctId: String, userDistinctId: String, properties: [String: String]) async throws {}
    func identify(distinctId: String, userProperties: [String: String]) async throws {}

    /// `AnalyticsService.track` delivers on a detached Task, so poll briefly.
    @MainActor
    func count(of name: String) async -> Int {
        for _ in 0..<25 {
            if events.contains(where: { $0.name == name }) { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return events.filter { $0.name == name }.count
    }
}

@MainActor
final class PricingFunnelEventsTests: XCTestCase {
    func testFunnelEventNamesAndPropertiesMatchTheContract() {
        let cases: [(AnalyticsEvent, String, [String: String])] = [
            (.onboardingStarted(entry: "home"), "onboarding_started", ["entry": "home"]),
            (.cvUploaded(method: "file"), "cv_uploaded", ["method": "file"]),
            (.cvUploaded(method: "sample"), "cv_uploaded", ["method": "sample"]),
            (.matchScoreViewed(source: "own", scoreBucket: "61-80"), "match_score_viewed", ["source": "own", "score_bucket": "61-80"]),
            (.pdfPreviewViewed(optimizationId: "opt-1", template: "minimal-ssr"), "pdf_preview_viewed", ["optimization_id": "opt-1", "template": "minimal-ssr"]),
            (.paywallViewed(entryPoint: "optimized", balance: 0), "paywall_viewed", ["entry_point": "optimized", "balance": "0"]),
            (.exportCompleted(optimizationId: "opt-1", source: "grant"), "export_completed", ["optimization_id": "opt-1", "source": "grant"]),
        ]
        for (event, name, properties) in cases {
            XCTAssertEqual(event.name, name)
            XCTAssertEqual(event.properties, properties, name)
        }
    }

    func testTheOldNamesStayForCurrentDashboards() {
        XCTAssertEqual(AnalyticsEvent.paywallShown(optimizationId: "o", balance: 0).name, "paywall_shown")
        XCTAssertEqual(AnalyticsEvent.exportSuccess(optimizationId: "o").name, "export_success")
        XCTAssertEqual(AnalyticsEvent.freeATSCompleted(scoreBucket: "41-60", hasURL: true, hasPaste: false).name, "free_ats_completed")
    }

    func testExportSourceNamesTheFreeExportsPacksProAndTheGateOff() {
        typealias R = ExportUnlockService.Response
        XCTAssertEqual(R(status: "unlocked", balance: 2, source: "welcome_grant").analyticsSource, "grant")
        XCTAssertEqual(R(status: "already_unlocked", balance: 2, source: "welcome_grant").analyticsSource, "grant")
        XCTAssertEqual(R(status: "unlocked", balance: 4, source: "credit").analyticsSource, "pack")
        XCTAssertEqual(R(status: "unlocked", balance: 0, source: "subscription").analyticsSource, "subscription")
        XCTAssertEqual(R(status: "ungated", balance: nil, source: "ungated").analyticsSource, "ungated")
        // A server before pricing v2 sends no source.
        XCTAssertEqual(R(status: "ungated", balance: nil).analyticsSource, "ungated")
        XCTAssertEqual(R(status: "unlocked", balance: 3).analyticsSource, "pack")
    }

    func testAnInstallUsedBeforeThisBuildIsNotANewUser() async {
        let defaults = UserDefaults(suiteName: "onboarding-existing-\(UUID().uuidString)")!
        defaults.set("anon-123", forKey: AnalyticsService.anonymousSessionIdKey)
        let transport = FunnelTransport()

        OnboardingStartedOnce.markExistingInstall(defaults: defaults)
        OnboardingStartedOnce.trackIfFirst(entry: "home", defaults: defaults, analytics: AnalyticsService(transport: transport))

        let count = await transport.count(of: "onboarding_started")
        XCTAssertEqual(count, 0)
    }

    func testAFreshInstallIsNotMarkedAtStart() {
        let defaults = UserDefaults(suiteName: "onboarding-fresh-\(UUID().uuidString)")!
        OnboardingStartedOnce.markExistingInstall(defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: OnboardingStartedOnce.key))
    }

    func testOnboardingStartedFiresOncePerInstall() async {
        let defaults = UserDefaults(suiteName: "onboarding-\(UUID().uuidString)")!
        let transport = FunnelTransport()
        let analytics = AnalyticsService(transport: transport)

        OnboardingStartedOnce.trackIfFirst(entry: "home", defaults: defaults, analytics: analytics)
        OnboardingStartedOnce.trackIfFirst(entry: "home", defaults: defaults, analytics: analytics)

        let count = await transport.count(of: "onboarding_started")
        XCTAssertEqual(count, 1)
        XCTAssertTrue(defaults.bool(forKey: OnboardingStartedOnce.key))
    }
}
