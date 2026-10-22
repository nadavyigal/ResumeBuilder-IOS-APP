import XCTest
@testable import ResumeBuilder_IOS_APP

/// Founder device test, 2026-10-21: a guest ran a check (résumé owned by the
/// anonymous user), signed in, and ran the same file and job. The app reused the
/// guest's cached résumé id, `/api/optimize` could not see it through the signed-in
/// user's RLS client, and answered "Resume not found" three times with no new
/// upload. These tests pin the fix: the cache belongs to one identity, it is
/// dropped when the identity changes, and a not-found re-uploads exactly once.
@MainActor
final class UploadCacheIdentityTests: XCTestCase {

    private let jobURL = "https://www.linkedin.com/jobs/view/4012345678"

    private func session(_ userId: String, anonymous: Bool = false) -> AuthSession {
        AuthSession(accessToken: "token-\(userId)", refreshToken: nil, userId: userId, email: nil, isAnonymous: anonymous)
    }

    private func makeModel(uploads: UploadSpy, optimizer: OptimizerSpy, events: EventLog = EventLog()) -> TailorViewModel {
        let model = TailorViewModel(optimizationService: optimizer, uploader: uploads.upload, track: events.record)
        model.selectedResumeURL = URL(fileURLWithPath: "/tmp/maya-resume.pdf")
        model.selectedResumeName = "maya-resume.pdf"
        model.jobDescriptionURL = jobURL
        return model
    }

    private func makeAppState(_ session: AuthSession?) -> AppState {
        let state = AppState(authClient: UploadCacheAuthClient())
        state.session = session
        return state
    }

    // MARK: Identity

    /// The reported bug: same file and job, a new identity, so a new upload.
    func testSignInAfterGuestCheckUploadsAgainForTheSameFileAndJob() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.success, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)
        let appState = makeAppState(session("anon-1", anonymous: true))

        await model.optimize(appState: appState)
        appState.session = session("user-2")
        await model.optimize(appState: appState)

        XCTAssertEqual(uploads.count, 2, "the signed-in user must upload their own copy")
        XCTAssertEqual(optimizer.resumeIds, ["resume-1", "resume-2"])
        XCTAssertNil(model.errorMessage)
    }

    /// Guard against over-correcting: the same identity, file and job reuse the upload.
    func testSameIdentityReusesTheUpload() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.success, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)
        let appState = makeAppState(session("user-2"))

        await model.optimize(appState: appState)
        await model.optimize(appState: appState)

        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(optimizer.resumeIds, ["resume-1", "resume-1"])
    }

    func testUploadIdentityIsTheUserIdOrGuest() {
        XCTAssertEqual(TailorViewModel.uploadIdentity(for: session("abc")), "user:abc")
        XCTAssertEqual(TailorViewModel.uploadIdentity(for: nil), "guest")
    }

    /// Sign-out (and sign-in, account deletion) reset the cache: the next check
    /// uploads again and no cached id survives.
    func testResetUploadCacheDropsEveryCachedId() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.success, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)
        let appState = makeAppState(session("user-2"))

        await model.optimize(appState: appState)
        XCTAssertNotNil(model.uploadResponse)
        XCTAssertNotNil(model.pendingSaveResumeId)

        model.resetUploadCache()
        XCTAssertNil(model.uploadResponse)
        XCTAssertNil(model.pendingSaveResumeId)
        XCTAssertEqual(model.selectedResumeName, "maya-resume.pdf", "the picked file stays")

        await model.optimize(appState: appState)
        XCTAssertEqual(uploads.count, 2)
    }

    // MARK: Not found

    func testResumeNotFoundReuploadsOnceAndRetries() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.resumeNotFound, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)
        let appState = makeAppState(session("user-2"))

        await model.optimize(appState: appState)

        XCTAssertEqual(uploads.count, 2, "one re-upload after the not-found")
        XCTAssertEqual(optimizer.resumeIds, ["resume-1", "resume-2"], "the retry uses the fresh ids")
        XCTAssertEqual(model.optimizationId, "opt-1")
        XCTAssertNil(model.errorMessage)
    }

    func testJobDescriptionNotFoundAlsoReuploadsOnce() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.jobNotFound, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)

        await model.optimize(appState: makeAppState(session("user-2")))

        XCTAssertEqual(uploads.count, 2)
        XCTAssertEqual(optimizer.callCount, 2)
        XCTAssertNil(model.errorMessage)
    }

    /// Never loop: a second not-found surfaces the error.
    func testSecondNotFoundSurfacesTheError() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.resumeNotFound, .resumeNotFound, .resumeNotFound])
        let model = makeModel(uploads: uploads, optimizer: optimizer)

        await model.optimize(appState: makeAppState(session("user-2")))

        XCTAssertEqual(uploads.count, 2, "exactly one re-upload")
        XCTAssertEqual(optimizer.callCount, 2, "exactly one retry")
        XCTAssertNil(model.optimizationId)
        XCTAssertNotNil(model.errorMessage)
    }

    /// Codex on PR #202: when the recovery upload itself fails, the funnel must
    /// record an upload failure, not leave `resume_upload_started` with no end.
    func testFailedRecoveryUploadIsRecordedAsAnUploadFailure() async {
        let uploads = UploadSpy(failOnCall: 2)
        let optimizer = OptimizerSpy(results: [.resumeNotFound])
        let events = EventLog()
        let model = makeModel(uploads: uploads, optimizer: optimizer, events: events)

        await model.optimize(appState: makeAppState(session("user-2")))

        XCTAssertEqual(uploads.count, 2)
        XCTAssertEqual(optimizer.callCount, 1, "no retry when the re-upload failed")
        XCTAssertEqual(events.names.filter { $0 == "resume_upload_started" }.count, 2)
        XCTAssertEqual(events.names.filter { $0 == "resume_upload_failed" }.count, 1,
                       "the failed recovery upload reaches the funnel")
        XCTAssertNotNil(model.errorMessage)
    }

    /// Codex P2 on #202: a cached upload from another identity forces a new
    /// upload. If that upload fails, the funnel gets `resume_upload_failed`, not
    /// a `resume_upload_started` with no end.
    func testFailedUploadAfterAnIdentityChangeIsRecordedAsAnUploadFailure() async {
        let uploads = UploadSpy(failOnCall: 2)
        let optimizer = OptimizerSpy(results: [.success])
        let events = EventLog()
        let model = makeModel(uploads: uploads, optimizer: optimizer, events: events)
        let appState = makeAppState(session("anon-1", anonymous: true))

        await model.optimize(appState: appState)
        appState.session = session("user-2")
        await model.optimize(appState: appState)

        XCTAssertEqual(uploads.count, 2)
        XCTAssertEqual(optimizer.callCount, 1, "no optimize when the new upload failed")
        XCTAssertEqual(events.names.filter { $0 == "resume_upload_started" }.count, 2)
        XCTAssertEqual(events.names.filter { $0 == "resume_upload_failed" }.count, 1,
                       "the failed replacement upload reaches the funnel")
        XCTAssertNotNil(model.errorMessage)
    }

    /// A second not-found after a good re-upload is an optimize failure, not an upload failure.
    func testSecondNotFoundIsNotRecordedAsAnUploadFailure() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.resumeNotFound, .resumeNotFound])
        let events = EventLog()
        let model = makeModel(uploads: uploads, optimizer: optimizer, events: events)

        await model.optimize(appState: makeAppState(session("user-2")))

        XCTAssertEqual(events.names.filter { $0 == "resume_upload_succeeded" }.count, 2)
        XCTAssertFalse(events.names.contains("resume_upload_failed"))
    }

    /// Other server errors do not trigger a re-upload.
    func testOtherServerErrorsDoNotReupload() async {
        let uploads = UploadSpy()
        let optimizer = OptimizerSpy(results: [.serverDown, .success])
        let model = makeModel(uploads: uploads, optimizer: optimizer)

        await model.optimize(appState: makeAppState(session("user-2")))

        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(optimizer.callCount, 1)
        XCTAssertNotNil(model.errorMessage)
    }

    func testNotFoundClassifierMatchesTheServerMessages() {
        XCTAssertTrue(TailorViewModel.isUploadedIdNotFound(APIClientError.serverError(status: 500, message: "Resume not found")))
        XCTAssertTrue(TailorViewModel.isUploadedIdNotFound(APIClientError.serverError(status: 404, message: "Job description not found")))
        XCTAssertTrue(TailorViewModel.isUploadedIdNotFound(APIClientError.serverError(status: 500, message: "resume NOT FOUND")))
        XCTAssertFalse(TailorViewModel.isUploadedIdNotFound(APIClientError.serverError(status: 500, message: "Function timed out")))
        XCTAssertFalse(TailorViewModel.isUploadedIdNotFound(APIClientError.serverError(status: 400, message: "Resume not found")))
        XCTAssertFalse(TailorViewModel.isUploadedIdNotFound(APIClientError.unauthorized))
        XCTAssertFalse(TailorViewModel.isUploadedIdNotFound(URLError(.timedOut)))
    }
}

// MARK: - Test doubles

@MainActor
private final class EventLog {
    private(set) var names: [String] = []
    var record: @MainActor (AnalyticsEvent) -> Void {
        { event in self.names.append(event.name) }
    }
}

@MainActor
private final class UploadSpy {
    private(set) var count = 0
    private let failOnCall: Int?

    init(failOnCall: Int? = nil) { self.failOnCall = failOnCall }

    var upload: TailorViewModel.ResumeUploader {
        { _, _, _, _ in
            self.count += 1
            let count = self.count
            if count == self.failOnCall { throw APIClientError.serverError(status: 502, message: "Bad gateway") }
            let json = #"{"success":true,"resumeId":"resume-\#(count)","jobDescriptionId":"job-\#(count)"}"#
            return try JSONDecoder().decode(ResumeUploadResponse.self, from: Data(json.utf8))
        }
    }
}

private final class OptimizerSpy: ResumeOptimizationServiceProtocol, @unchecked Sendable {
    enum Result { case success, resumeNotFound, jobNotFound, serverDown }

    private let lock = NSLock()
    private var results: [Result]
    private var _resumeIds: [String] = []

    init(results: [Result]) { self.results = results }

    var resumeIds: [String] { lock.lock(); defer { lock.unlock() }; return _resumeIds }
    var callCount: Int { resumeIds.count }

    private func next(resumeId: String) -> Result {
        lock.lock(); defer { lock.unlock() }
        _resumeIds.append(resumeId)
        return results.isEmpty ? .success : results.removeFirst()
    }

    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
        switch next(resumeId: resumeId) {
        case .success:
            return OptimizeResponse(success: true, sections: [], optimizationId: "opt-1", error: nil)
        case .resumeNotFound:
            throw APIClientError.serverError(status: 500, message: "Resume not found")
        case .jobNotFound:
            throw APIClientError.serverError(status: 500, message: "Job description not found")
        case .serverDown:
            throw APIClientError.serverError(status: 503, message: "Service unavailable")
        }
    }

    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse {
        throw URLError(.unsupportedURL)
    }

    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool { false }
}

private final class UploadCacheAuthClient: AuthClient, @unchecked Sendable {
    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func refreshSession(refreshToken: String) async throws -> AuthSession { throw URLError(.notConnectedToInternet) }
    func deleteAccount(accessToken: String) async throws {}
}
