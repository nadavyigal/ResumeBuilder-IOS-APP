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
        // Properties are [String: Any] because `$set` is a nested object (WP-63).
        let anyProps = payload["properties"] as? [String: Any]
        let props = anyProps?.compactMapValues { $0 as? String }
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

    // MARK: WP-63 — the person property every "clean" insight depends on

    /// WP-63 story 5, measured 2026-07-29 on PostHog 270848: `is_internal_tester`
    /// was `true` on **108 persons** by event property and **3** by person
    /// property. Every saved insight excludes testers with
    /// `{"key": "is_internal_tester", "type": "person", "operator": "is_not"}`,
    /// so all of them — "Clean User Lifecycle", "Clean Current-Build Activation",
    /// "Web — Export Funnel (founder-excluded)" — were excluding 3 of 108 and
    /// over-counting the clean population by roughly 40%.
    ///
    /// Cause: `$set` rode only on `$identify`, and `$identify` fires only when a
    /// user authenticates. The 108 are per-build test sweeps that overwhelmingly
    /// never sign in, so the person property was never written for them.
    ///
    /// Fixing this at the insight level instead — switching those filters to
    /// event-level — would reintroduce the 2026-07-28 defect where one person
    /// lands on both sides of an exclusion. The flag has to reach the person.
    func testEveryEventSetsTheInternalTesterPersonPropertySoAnonymousTestersAreExcludable() async {
        UserDefaults.standard.set(true, forKey: AnalyticsService.internalTesterKey)
        UserDefaults.standard.set("anon-123", forKey: AnalyticsService.anonymousSessionIdKey)
        defer { UserDefaults.standard.removeObject(forKey: AnalyticsService.internalTesterKey) }

        let payload = AnalyticsService.buildCapturePayload(
            apiKey: "phc_test",
            event: .appLaunched(isAuthenticated: false),
            distinctId: "anon-123"
        )
        let props = payload["properties"] as? [String: Any]
        let set = props?["$set"] as? [String: String]
        XCTAssertEqual(set?["is_internal_tester"], "true",
            "an ordinary event must set the person property, or anonymous testers "
            + "stay invisible to every person-level exclusion filter")
    }

    /// The invariant that actually matters, and the one that was broken: the
    /// person property must AGREE with the event property on the same payload.
    ///
    /// Asserting a literal "false" here would be wrong — `currentInternalTesterValue()`
    /// also consults TestFlight receipt and a configured user-id list, so the
    /// resolved value is environment-dependent. Agreement is not.
    func testThePersonPropertyAlwaysAgreesWithTheEventProperty() async {
        UserDefaults.standard.set("anon-456", forKey: AnalyticsService.anonymousSessionIdKey)

        for flag in [true, false] {
            UserDefaults.standard.set(flag, forKey: AnalyticsService.internalTesterKey)
            let payload = AnalyticsService.buildCapturePayload(
                apiKey: "phc_test",
                event: .appLaunched(isAuthenticated: false),
                distinctId: "anon-456"
            )
            let props = payload["properties"] as? [String: Any]
            let eventValue = props?["is_internal_tester"] as? String
            let personValue = (props?["$set"] as? [String: String])?["is_internal_tester"]
            XCTAssertNotNil(personValue, "every event must carry the person-scoped $set")
            XCTAssertEqual(personValue, eventValue,
                "person and event property must agree — they disagreed 108 vs 3 in "
                + "production, which silently broke every person-level exclusion filter")
        }
        UserDefaults.standard.removeObject(forKey: AnalyticsService.internalTesterKey)
    }

    /// Regression for the race CodeRabbit caught on PR #137: `track(_:)` snapshots
    /// the event property and then hands off to an async Task, so a sign-in or
    /// reset landing in between must not make the person value disagree with the
    /// event value on the same payload. Flipping the flag between assembly and
    /// `withPersonScope` reproduces exactly that window.
    func testPersonScopeUsesThePayloadSnapshotNotAFreshRead() async {
        UserDefaults.standard.set(true, forKey: AnalyticsService.internalTesterKey)
        let assembled = ["is_internal_tester": "true", "app": "resumely_ios"]

        // The window: state changes after the event was assembled.
        UserDefaults.standard.set(false, forKey: AnalyticsService.internalTesterKey)
        defer { UserDefaults.standard.removeObject(forKey: AnalyticsService.internalTesterKey) }

        let out = PostHogAnalyticsTransport.withPersonScope(assembled)
        let personValue = (out["$set"] as? [String: String])?["is_internal_tester"]
        XCTAssertEqual(personValue, "true",
            "the person value must come from the payload that was assembled, not from "
            + "a re-read that can race the async transport")
        XCTAssertEqual(personValue, out["is_internal_tester"] as? String,
            "person and event values must agree on the same payload by construction")
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
            "analysis_cta_tapped",
            "job_input_validation_shown",
            "free_ats_completed",
            "score_screen_signin_tapped",
            "sign_in_completed",
            "account_deleted",
            "optimization_started",
            "optimization_completed",
            "optimization_state_recovered",
            "optimization_state_recovery_failed",
            "optimization_apply_started",
            "optimization_apply_succeeded",
            "optimization_apply_failed",
            "optimized_viewed",
            "optimized_preview_rendered",
            "saved_resume_prompt_viewed",
            "save_started",
            "save_success",
            "save_failed",
            "export_started",
            "export_success",
            "app_store_review_requested",
            "export_failed",
            "diagnosis_viewed",
            "recommendation_viewed",
            "recommendation_included",
            "recommendation_edited",
            "recommendation_skipped",
            "recommendation_blocked",
            "recommendation_evidence_shown",
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
            "second_job_started",
        ]
        XCTAssertEqual(Self.allAnalyticsEvents.map(\.name), expectedNames)
    }

    func testAllEventPropertiesMatchPostHogContract() async {
        let expectedProperties: [[String: String]] = [
            ["is_authenticated": "true"],
            [:],
            ["file_type": "pdf"],
            ["has_url": "true", "has_paste": "false"],
            [
                "source": "home",
                "flow_version": "fit_gate_v1",
                "job_input_source": "url",
                "extraction_quality": "unknown",
                "requirement_count_bucket": "unknown",
                "score_version": "ats_v2_legacy",
            ],
            ["surface": "home", "reason": "description_too_short"],
            ["score_bucket": "61-80", "job_source": "url"],
            ["source": "home", "score_bucket": "61-80"],
            [:],
            [:],
            ["resume_id": "resume-1", "job_description_id": "job-1", "job_source": "url"],
            // `path` separates the two moments this event name covers, and
            // `emitter` separates the client copy from the backend's.
            ["optimization_id": "opt-1", "review_id": "review-1", "path": "applied", "emitter": "client"],
            ["optimization_id": "opt-1"],
            ["reason": "network", "error_code": "network_1009"],
            ["review_id": "review-1", "approved_group_count": "2"],
            ["optimization_id": "opt-1", "review_id": "review-1"],
            ["review_id": "review-1", "reason": "server_error", "error_code": "server_500"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1", "reason": "network", "error_code": "network_1009"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["source": "export_success"],
            ["optimization_id": "opt-1", "error_code": "unauthorized"],
            ["match_score": "72"],
            ["surface": "optimization_review", "safety_state": "safe", "review_id": "review-1", "item_id": "item-1"],
            ["surface": "optimization_review", "safety_state": "confirmation_required", "evidence_state": "with_evidence", "review_id": "review-1", "item_id": "item-1"],
            ["surface": "optimization_review", "safety_state": "confirmation_required", "review_id": "review-1", "item_id": "item-1"],
            ["surface": "optimization_review", "safety_state": "safe", "evidence_state": "without_evidence", "review_id": "review-1", "item_id": "item-1"],
            ["surface": "optimization_review", "reason": "unresolved_placeholder", "review_id": "review-1", "item_id": "item-1"],
            ["surface": "optimization_review", "job_quote_count": "2", "resume_quote_count": "1", "review_id": "review-1", "item_id": "item-1"],
            ["current_score": "55"],
            ["optimization_id": "opt-1"],
            ["optimization_id": "opt-1"],
            ["has_cover_letter": "true"],
            ["flow_version": "fit_gate_v1", "score_version": "ats_v2_legacy"],
            ["verdict": "stretch", "match_score": "68", "score_bucket": "61-80", "flow_version": "fit_gate_v1", "score_version": "ats_v2_legacy"],
            [:],
            [:],
            ["source": "home"],
            ["source": "home", "file_type": "none", "file_size_bucket": "none"],
            ["source": "home", "file_type": "pdf", "file_size_bucket": "100kb-1mb"],
            ["source": "home", "file_type": "pdf", "file_size_bucket": "100kb-1mb"],
            ["reason": "unreadable"],
            ["file_type": "pdf"],
            ["failure_stage": "upload", "error_code": "500"],
            ["file_type": "pdf"],
            ["error_code": "500"],
            ["source": "home"],
            ["route": "scan"],
            ["source": "home"],
            [:],
        ]
        XCTAssertEqual(Self.allAnalyticsEvents.map(\.properties), expectedProperties)
    }

    // MARK: Internal tester identification

    /// QA accounts here are plus-aliases of one address, so the allowlist has to
    /// fold them together or it drifts stale the first time someone makes a new
    /// one. This is the matching rule the email allowlist depends on.
    func testPlusAliasesNormaliseToTheBaseAddress() {
        XCTAssertEqual(
            AnalyticsService.normalizedEmail("nadav.yigal+fable-qa-jul03@gmail.com"),
            "nadav.yigal@gmail.com"
        )
        XCTAssertEqual(
            AnalyticsService.normalizedEmail("  NADAV.YIGAL@GmAiL.com "),
            "nadav.yigal@gmail.com",
            "Case and surrounding whitespace must not create a second identity"
        )
        XCTAssertEqual(AnalyticsService.normalizedEmail("a+b+c@example.com"), "a@example.com")
    }

    func testMalformedEmailsNormaliseToNothingRatherThanMatchingLoosely() {
        // A rule that returned "" or the raw string here could match an empty or
        // malformed allowlist entry and mark a real user internal, which silently
        // deletes them from the activation numbers.
        XCTAssertNil(AnalyticsService.normalizedEmail(nil))
        XCTAssertNil(AnalyticsService.normalizedEmail(""))
        XCTAssertNil(AnalyticsService.normalizedEmail("   "))
        XCTAssertNil(AnalyticsService.normalizedEmail("no-at-sign"))
        XCTAssertNil(AnalyticsService.normalizedEmail("+only@example.com"))
    }

    // MARK: Impression deduplication

    /// One optimization, one impression — regardless of how many views claim it.
    ///
    /// The guard used to be a `@State` Set on the view, which meant a rebuilt
    /// view re-fired. During the tab swap after an apply, two views for two
    /// different optimizations were briefly alive and both reported themselves
    /// seen, so `optimized_viewed` and `export_cta_seen` arrived twice with one
    /// copy carrying the previous optimization's id (device, 1.4.9, 2026-08-12).
    func testImpressionIsClaimedOncePerOptimization() {
        let log = ImpressionLog()

        XCTAssertTrue(log.claim("optimized_viewed", id: "opt-1"))
        XCTAssertFalse(log.claim("optimized_viewed", id: "opt-1"), "A second view must not re-fire")
        XCTAssertFalse(log.claim("optimized_viewed", id: "opt-1"))
    }

    func testImpressionsAreIndependentPerEventAndPerOptimization() {
        let log = ImpressionLog()

        XCTAssertTrue(log.claim("optimized_viewed", id: "opt-1"))
        XCTAssertTrue(log.claim("export_cta_seen", id: "opt-1"), "A different event is a different impression")
        XCTAssertTrue(log.claim("optimized_viewed", id: "opt-2"), "A different optimization is a different impression")
        XCTAssertFalse(log.claim("optimized_viewed", id: "opt-1"))
    }

    // MARK: Test traffic must not reach production analytics

    /// Local and CI test runs were registering as real people in the production
    /// project — three runs on 2026-08-12 produced three "users" of 61, 61 and
    /// 57 events, walking most of the funnel in under a second. That traffic is
    /// indistinguishable from real users in aggregate and is why the funnel
    /// denominators here could not be trusted.
    func testAnalyticsIsDisabledUnderTest() {
        XCTAssertTrue(AnalyticsService.isRunningTests, "This assertion runs inside XCTest by definition")
        XCTAssertFalse(
            AnalyticsService().isEnabled,
            "A default-initialised service must not build a live transport during a test run"
        )
    }

    func testInjectedTransportStillWinsUnderTest() {
        // Tests that assert on tracking must still be able to observe it.
        XCTAssertTrue(AnalyticsService(transport: SpyTransport()).isEnabled)
    }

    // MARK: Service enabled state

    func testServiceIsEnabledWhenTransportIsProvided() async {
        let service = AnalyticsService(transport: SpyTransport())
        XCTAssertTrue(service.isEnabled)
        service.track(.resumeUploaded(fileType: "pdf")) // must not crash
    }

    func testCanonicalLifecycleEventsCarryOnlyStableNonContentCorrelation() {
        XCTAssertEqual(
            AnalyticsEvent.optimizationApplyStarted(reviewId: "review-1", approvedGroupCount: 3).properties,
            ["review_id": "review-1", "approved_group_count": "3"]
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizationApplyFailed(reviewId: "review-1", reason: "network", errorCode: "network_1009").properties,
            ["review_id": "review-1", "reason": "network", "error_code": "network_1009"]
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizedPreviewRendered(optimizationId: "opt-1").properties,
            ["optimization_id": "opt-1"]
        )
        XCTAssertEqual(
            AnalyticsEvent.saveFailed(optimizationId: "opt-1", reason: "server_error", errorCode: "server_500").properties,
            ["optimization_id": "opt-1", "reason": "server_error", "error_code": "server_500"]
        )
        XCTAssertEqual(
            AnalyticsEvent.exportSuccess(optimizationId: "opt-1").properties,
            ["optimization_id": "opt-1"]
        )
    }

    func testValidationAndRecommendationEventsUseBoundedCategoriesAndIds() {
        XCTAssertEqual(
            AnalyticsEvent.jobInputValidationShown(surface: "home", reason: "description_too_short").properties,
            ["surface": "home", "reason": "description_too_short"]
        )
        XCTAssertEqual(
            AnalyticsEvent.recommendationIncluded(
                surface: "optimization_review",
                safetyState: "safe",
                evidenceState: "with_evidence",
                reviewId: "review-1",
                itemId: "summary-1"
            ).properties,
            [
                "surface": "optimization_review",
                "safety_state": "safe",
                "evidence_state": "with_evidence",
                "review_id": "review-1",
                "item_id": "summary-1",
            ]
        )
    }

    /// WP-52: these three events fired with no diagnostic payload in every build shipped to
    /// date. `error_code` landed in 31b73b6 but has not reached users yet (it first ships in
    /// 1.4.4, still in review); `reason` is added here. Both must be present so a failure can
    /// be read as a groupable bucket and as a specific code.
    func testFailureEventsCarryBothReasonAndErrorCode() {
        XCTAssertEqual(
            AnalyticsEvent.saveFailed(
                optimizationId: "opt-1", reason: "offline", errorCode: "network_1009"
            ).properties,
            ["optimization_id": "opt-1", "reason": "offline", "error_code": "network_1009"]
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizationApplyFailed(
                reviewId: "review-1", reason: "backend_rejected", errorCode: "backend_error"
            ).properties,
            ["review_id": "review-1", "reason": "backend_rejected", "error_code": "backend_error"]
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizationStateRecoveryFailed(
                reason: "auth", errorCode: "unauthorized"
            ).properties,
            ["reason": "auth", "error_code": "unauthorized"]
        )
    }

    func testFailureReasonBucketsErrorsIntoGroupableCategories() {
        XCTAssertEqual(FailureReason.reason(for: APIClientError.unauthorized), "auth")
        XCTAssertEqual(FailureReason.reason(for: APIClientError.paymentRequired), "entitlement")
        XCTAssertEqual(
            FailureReason.reason(for: APIClientError.serverError(status: 500, message: "")),
            "server_error"
        )
        XCTAssertEqual(
            FailureReason.reason(for: APIClientError.serverError(status: 422, message: "")),
            "client_rejected"
        )
        XCTAssertEqual(
            FailureReason.reason(for: URLError(.timedOut)),
            "timeout"
        )
        XCTAssertEqual(
            FailureReason.reason(for: URLError(.notConnectedToInternet)),
            "offline"
        )
        XCTAssertEqual(
            FailureReason.reason(for: NSError(domain: "com.example.other", code: 7)),
            "unknown"
        )
    }

    func testLocalSelectionAndServerUploadCompletionRemainDistinctEvents() {
        XCTAssertEqual(
            AnalyticsEvent.resumeFileSelected(source: "home", fileType: "pdf", sizeBucket: "100kb-1mb").name,
            "resume_file_selected"
        )
        XCTAssertEqual(
            AnalyticsEvent.resumeUploadSucceeded(fileType: "pdf").name,
            "resume_upload_succeeded"
        )
        XCTAssertNotEqual(
            AnalyticsEvent.resumeFileSelected(source: "home", fileType: "pdf", sizeBucket: "100kb-1mb").name,
            AnalyticsEvent.resumeUploadSucceeded(fileType: "pdf").name
        )
    }

    /// The upload step is only a measurable funnel when its impression, picker,
    /// and terminal selection can be joined to the same reachable surface.
    func testUploadFunnelEndsArePairableOnSource() {
        let source = "home"
        let ctaSeen = AnalyticsEvent.resumeUploadCTASeen(source: source).properties
        let pickerOpened = AnalyticsEvent.resumeFilePickerOpened(
            source: source,
            fileType: "none",
            sizeBucket: "none"
        ).properties
        let fileSelected = AnalyticsEvent.resumeFileSelected(
            source: source,
            fileType: "docx",
            sizeBucket: "100kb-1mb"
        ).properties

        XCTAssertEqual(ctaSeen["source"], source)
        XCTAssertEqual(pickerOpened["source"], source)
        XCTAssertEqual(fileSelected["source"], source)
        XCTAssertEqual(fileSelected["file_type"], "docx")
        XCTAssertEqual(fileSelected["file_size_bucket"], "100kb-1mb")
    }

    // MARK: WP-48 S2 instrumentation

    /// The score screen tells a session-less guest to sign in before it will
    /// optimize. That wall had no event, so every guest who saw their score and
    /// stopped there was indistinguishable from one who never got a score —
    /// the tap is the only thing separating "saw the wall" from "accepted it".
    func testScoreScreenSignInTapIsNamedAndJoinableToTheScoreShown() {
        let event = AnalyticsEvent.scoreScreenSignInTapped(source: "home", scoreBucket: "0-40")

        XCTAssertEqual(event.name, "score_screen_signin_tapped")
        XCTAssertEqual(event.properties["source"], "home")
        XCTAssertEqual(
            event.properties["score_bucket"],
            "0-40",
            "Without the bucket the wall cannot be read against the score that produced it"
        )
    }

    /// A picker that opens and is cancelled means two different things depending
    /// on whether the user was already holding a résumé: nothing-to-nothing is a
    /// real drop-off, replacement-abandoned is not. Same keys as the outcome
    /// events so the whole picker step joins on one set of columns.
    func testPickerOpenAndCancelDescribeTheResumeHeldAtThatMoment() {
        let emptyHanded = AnalyticsEvent.resumeFilePickerOpened(
            source: "home",
            fileType: "none",
            sizeBucket: "none"
        ).properties
        XCTAssertEqual(emptyHanded["source"], "home")
        XCTAssertEqual(emptyHanded["file_type"], "none")
        XCTAssertEqual(emptyHanded["file_size_bucket"], "none")

        let replacing = AnalyticsEvent.resumeFilePickerCancelled(
            source: "home",
            fileType: "docx",
            sizeBucket: "1mb-5mb"
        ).properties
        XCTAssertEqual(replacing["source"], "home")
        XCTAssertEqual(replacing["file_type"], "docx")
        XCTAssertEqual(replacing["file_size_bucket"], "1mb-5mb")
    }

    /// The descriptor the picker events carry, measured off a real file.
    func testHeldResumeDescriptorBucketsARealFileAndReportsNoneWhenEmptyHanded() throws {
        let empty = TailorViewModel.heldResumeDescriptor(for: nil)
        XCTAssertEqual(empty.fileType, "none")
        XCTAssertEqual(empty.sizeBucket, "none")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("held-resume-\(UUID().uuidString).docx")
        try Data(repeating: 0x41, count: 200_000).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let held = TailorViewModel.heldResumeDescriptor(for: url)
        XCTAssertEqual(held.fileType, "docx")
        XCTAssertEqual(held.sizeBucket, "100kb-1mb")
    }

    /// A URL and a pasted description are not the same input: one is scraped
    /// server-side and can fail or come back thin. Both the free check and the
    /// paid run have to say which one they were fed, or a difference in outcome
    /// between them is unattributable.
    func testFreeCheckAndOptimizeStartRecordWhichJobInputWasUsed() {
        XCTAssertEqual(
            AnalyticsEvent.freeATSCompleted(scoreBucket: "41-60", hasURL: true, hasPaste: false)
                .properties["job_source"],
            "url"
        )
        XCTAssertEqual(
            AnalyticsEvent.freeATSCompleted(scoreBucket: "41-60", hasURL: false, hasPaste: true)
                .properties["job_source"],
            "paste"
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizationStarted(
                resumeId: "resume-1",
                jobDescriptionId: "job-1",
                hasURL: true,
                hasPaste: true
            ).properties["job_source"],
            "url_and_paste"
        )
        XCTAssertEqual(
            AnalyticsEvent.optimizationStarted(
                resumeId: "resume-1",
                jobDescriptionId: "job-1",
                hasURL: false,
                hasPaste: false
            ).properties["job_source"],
            "none"
        )
    }

    /// WP-51 regression. The preview renders from the optimization id alone, so a real
    /// résumé is on screen while `sections` — and therefore the old
    /// `hasVisibleAppliedChanges` gate — is still empty. The milestone must fire anyway,
    /// otherwise `export_success` outruns it and the activation funnel is non-monotonic.
    func testPreviewActivationPolicyFiresOnBackendRenderWithoutLoadedSections() {
        var policy = PreviewActivationPolicy()

        XCTAssertEqual(
            policy.consumeVisibleRender(
                optimizationId: "opt-1",
                renderedHTML: Self.backendRenderedResumeHTML,
                isActive: true
            ),
            "opt-1"
        )
    }

    /// The gate still has to reject a webview that finished loading chrome with no
    /// résumé in it — otherwise the fix trades under-firing for over-firing.
    func testPreviewActivationPolicyIgnoresRendersWithNoVisibleText() {
        var policy = PreviewActivationPolicy()

        XCTAssertNil(policy.consumeVisibleRender(optimizationId: "opt-1", renderedHTML: nil, isActive: true))
        XCTAssertNil(policy.consumeVisibleRender(optimizationId: "opt-1", renderedHTML: "", isActive: true))
        XCTAssertNil(
            policy.consumeVisibleRender(
                optimizationId: "opt-1",
                renderedHTML: Self.styleOnlyHTML,
                isActive: true
            )
        )
    }

    func testPreviewActivationPolicyGatesInactiveTabAndDeduplicatesByOptimization() {
        var policy = PreviewActivationPolicy()
        let html = Self.backendRenderedResumeHTML

        XCTAssertNil(policy.consumeVisibleRender(optimizationId: nil, renderedHTML: html, isActive: true))
        XCTAssertNil(policy.consumeVisibleRender(optimizationId: "   ", renderedHTML: html, isActive: true))
        XCTAssertNil(policy.consumeVisibleRender(optimizationId: "opt-1", renderedHTML: html, isActive: false))
        XCTAssertEqual(policy.consumeVisibleRender(optimizationId: "opt-1", renderedHTML: html, isActive: true), "opt-1")
        XCTAssertNil(policy.consumeVisibleRender(optimizationId: "opt-1", renderedHTML: html, isActive: true))
        XCTAssertEqual(policy.consumeVisibleRender(optimizationId: "opt-2", renderedHTML: html, isActive: true), "opt-2")
    }

    private static let backendRenderedResumeHTML = """
    <html><head><style>body{font-family:-apple-system;margin:0}</style></head>
    <body><h1>Dana Cohen</h1><h2>Experience</h2>
    <p>Led the migration of a payments platform serving 2M monthly users.</p></body></html>
    """

    /// Long enough to pass a naive length check, but carries no visible résumé text.
    private static let styleOnlyHTML = """
    <html><head><style>
    body{font-family:-apple-system;margin:0;padding:48px;color:#111}
    h1{font-size:28px;letter-spacing:-0.02em;margin-bottom:4px}
    section{page-break-inside:avoid;margin-bottom:24px}
    </style></head><body></body></html>
    """

    func testAnalyticsFlowVersionFollowsFitCheckRoute() {
        XCTAssertEqual(AnalyticsFlowVersion.current(isFitCheckEnabled: true), .fitGateV1)
        XCTAssertEqual(AnalyticsFlowVersion.current(isFitCheckEnabled: false), .directOptimizeV2)
    }

    func testJobInputValidationTrackingPolicyEmitsOnReasonTransitions() {
        var policy = JobInputValidationTrackingPolicy()

        XCTAssertEqual(policy.consume(.missing), "missing")
        XCTAssertNil(policy.consume(.missing))
        XCTAssertEqual(policy.consume(.descriptionTooShort), "description_too_short")
        XCTAssertNil(policy.consume(nil))
        XCTAssertEqual(policy.consume(.descriptionTooShort), "description_too_short")
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
        .analysisCTATapped(source: "home", flowVersion: .fitGateV1, hasURL: true, hasPaste: false),
        .jobInputValidationShown(surface: "home", reason: "description_too_short"),
        .freeATSCompleted(scoreBucket: "61-80", hasURL: true, hasPaste: false),
        .scoreScreenSignInTapped(source: "home", scoreBucket: "61-80"),
        .signInCompleted,
        .accountDeleted,
        .optimizationStarted(resumeId: "resume-1", jobDescriptionId: "job-1", hasURL: true, hasPaste: false),
        .optimizationCompleted(optimizationId: "opt-1", reviewId: "review-1", path: .applied),
        .optimizationStateRecovered(optimizationId: "opt-1"),
        .optimizationStateRecoveryFailed(reason: "network", errorCode: "network_1009"),
        .optimizationApplyStarted(reviewId: "review-1", approvedGroupCount: 2),
        .optimizationApplySucceeded(optimizationId: "opt-1", reviewId: "review-1"),
        .optimizationApplyFailed(reviewId: "review-1", reason: "server_error", errorCode: "server_500"),
        .optimizedViewed(optimizationId: "opt-1"),
        .optimizedPreviewRendered(optimizationId: "opt-1"),
        .savedResumePromptViewed(optimizationId: "opt-1"),
        .saveStarted(optimizationId: "opt-1"),
        .saveSuccess(optimizationId: "opt-1"),
        .saveFailed(optimizationId: "opt-1", reason: "network", errorCode: "network_1009"),
        .exportStarted(optimizationId: "opt-1"),
        .exportSuccess(optimizationId: "opt-1"),
        .appStoreReviewRequested(source: "export_success"),
        .exportFailed(optimizationId: "opt-1", errorCode: "unauthorized"),
        .diagnosisViewed(matchScore: 72),
        .recommendationViewed(surface: "optimization_review", safetyState: "safe", reviewId: "review-1", itemId: "item-1"),
        .recommendationIncluded(surface: "optimization_review", safetyState: "confirmation_required", evidenceState: "with_evidence", reviewId: "review-1", itemId: "item-1"),
        .recommendationEdited(surface: "optimization_review", safetyState: "confirmation_required", reviewId: "review-1", itemId: "item-1"),
        .recommendationSkipped(surface: "optimization_review", safetyState: "safe", evidenceState: "without_evidence", reviewId: "review-1", itemId: "item-1"),
        .recommendationBlocked(surface: "optimization_review", reason: "unresolved_placeholder", reviewId: "review-1", itemId: "item-1"),
        .recommendationEvidenceShown(surface: "optimization_review", jobQuoteCount: 2, resumeQuoteCount: 1, reviewId: "review-1", itemId: "item-1"),
        .atsImproveTapped(currentScore: 55),
        .exportPdfTapped(optimizationId: "opt-1"),
        .exportCTASeen(optimizationId: "opt-1"),
        .submitPackageSaved(hasCoverLetter: true),
        .fitCheckStarted,
        .fitCheckCompleted(verdict: "stretch", matchScore: 68),
        .fitCheckOptimizeTapped,
        .fitCheckSkipped,
        .resumeUploadCTATapped(source: "home"),
        .resumeFilePickerOpened(source: "home", fileType: "none", sizeBucket: "none"),
        .resumeFilePickerCancelled(source: "home", fileType: "pdf", sizeBucket: "100kb-1mb"),
        .resumeFileSelected(source: "home", fileType: "pdf", sizeBucket: "100kb-1mb"),
        .resumeUploadPreflightRejected(reason: "unreadable"),
        .resumeUploadStarted(fileType: "pdf"),
        .resumeUploadFailed(failureStage: "upload", errorCode: "500"),
        .resumeUploadSucceeded(fileType: "pdf"),
        .resumeUploadErrorShown(errorCode: "500"),
        .resumeUploadSheetDismissed(source: "home"),
        .resumeUploadComingSoonTapped(route: "scan"),
        .resumeUploadCTASeen(source: "home"),
        .secondJobStarted,
    ]

    private func resetAnalyticsDefaults() {
        UserDefaults.standard.removeObject(forKey: AnalyticsService.distinctIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.anonymousSessionIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.authenticatedUserIdKey)
        UserDefaults.standard.removeObject(forKey: AnalyticsService.internalTesterKey)
    }
}
