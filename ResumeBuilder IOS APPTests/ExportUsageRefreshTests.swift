import XCTest
@testable import ResumeBuilder_IOS_APP

// Founder Sandbox test on a real iPhone, 2026-11-03: right after an export the
// Profile plan row kept the old count until the app was relaunched. The unlock
// reply carries the credit balance but not Pro's fair-use count, and the plan
// row read the server once per launch.

private final class UsageRequestBox: @unchecked Sendable {
    var paths: [String] = []
}

/// Answers by path: the unlock call and the credits read get different bodies.
private final class UsageMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var unlockJSON = "{}"
    nonisolated(unsafe) static var creditsJSON = "{}"
    nonisolated(unsafe) static var box = UsageRequestBox()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.box.paths.append(path)
        let json = path.hasSuffix("/exports/unlock") ? Self.unlockJSON : Self.creditsJSON
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class ExportUsageRefreshTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let userId = "11111111-1111-4111-8111-111111111111"

    private func makeAppState(unlock: String, credits: String, box: UsageRequestBox) -> (AppState, ExportUnlockService) {
        UsageMockURLProtocol.unlockJSON = unlock
        UsageMockURLProtocol.creditsJSON = credits
        UsageMockURLProtocol.box = box
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UsageMockURLProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: config))
        let appState = AppState(apiClient: client)
        appState.session = AuthSession(accessToken: "tok", refreshToken: "r", userId: userId, email: "a@example.com")
        return (appState, ExportUnlockService(apiClient: client))
    }

    private func planRow(_ appState: AppState) -> PlanSummary {
        PlanSummary.make(subscription: appState.subscription, balance: appState.creditsBalance, locale: english)
    }

    func testAProExportUpdatesTheProfileUsageWithoutARelaunch() async throws {
        let box = UsageRequestBox()
        let (appState, service) = makeAppState(
            unlock: #"{"status":"unlocked","balance":0,"source":"subscription"}"#,
            credits: #"{"balance":0,"transactions":[],"subscription":{"active":true,"productId":"resumely.pro.monthly","expiresAt":"2026-11-29T10:00:00+00:00","autoRenew":true,"periodExports":1,"periodCap":40}}"#,
            box: box
        )
        appState.subscription = SubscriptionStatus(
            active: true,
            productId: ResumelyProducts.proMonthly,
            expiresAt: "2026-11-29T10:00:00+00:00",
            autoRenew: true,
            periodExports: 0,
            periodCap: 40
        )
        XCTAssertEqual(planRow(appState).detail, "0 of 40 PDF downloads used this period (fair use)")

        try await appState.authorizeExport(optimizationId: "opt-1", service: service)
        await appState.creditsRefreshAfterExport?.value

        XCTAssertEqual(planRow(appState).detail, "1 of 40 PDF downloads used this period (fair use)")
        XCTAssertEqual(box.paths, ["/api/v1/exports/unlock", "/api/v1/credits"])
    }

    func testAPackExportUpdatesTheProfileCountWithoutARelaunch() async throws {
        let box = UsageRequestBox()
        let (appState, service) = makeAppState(
            unlock: #"{"status":"unlocked","balance":2,"source":"credit"}"#,
            credits: #"{"balance":2,"transactions":[]}"#,
            box: box
        )
        appState.creditsBalance = 3
        XCTAssertEqual(planRow(appState).headline, "3 PDF downloads left")

        try await appState.authorizeExport(optimizationId: "opt-1", service: service)
        await appState.creditsRefreshAfterExport?.value

        XCTAssertEqual(planRow(appState).headline, "2 PDF downloads left")
        XCTAssertEqual(box.paths, ["/api/v1/exports/unlock", "/api/v1/credits"])
    }

    /// A repeat export of an unlocked résumé spends nothing, so there is
    /// nothing new to read.
    func testARepeatExportDoesNotReReadTheServer() async throws {
        let box = UsageRequestBox()
        let (appState, service) = makeAppState(
            unlock: #"{"status":"already_unlocked","balance":2,"source":"credit"}"#,
            credits: #"{"balance":2,"transactions":[]}"#,
            box: box
        )

        try await appState.authorizeExport(optimizationId: "opt-1", service: service)
        await appState.creditsRefreshAfterExport?.value

        XCTAssertEqual(appState.creditsBalance, 2)
        XCTAssertEqual(box.paths, ["/api/v1/exports/unlock"])
    }
}
