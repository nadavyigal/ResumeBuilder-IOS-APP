import Foundation
import Observation

@Observable
@MainActor
final class TailorViewModel {
    var selectedResumeURL: URL?
    var selectedResumeName: String?
    var jobDescriptionURL = ""
    var jobDescription = ""
    var isOptimizing = false

    /// Set when the server returns a review-based flow result. Drives navigation to `OptimizationReviewView`.
    var reviewId: String?
    /// The fit check measured by this optimize run: where the resume stands
    /// today against this job, and where accepting the rewrite takes it.
    var fitPreview: OptimizeFitPreview?
    /// Set when the server runs the direct flow (no diff review). Drives navigation to `OptimizedResumeView`.
    var optimizationId: String?

    var uploadResponse: ResumeUploadResponse?
    var errorMessage: String?
    var uploadFailureReason: UploadFailureReason?
    var failedResumeName: String?
    /// True when the most recent optimize/ATS-check failure was a connectivity drop
    /// (not a server or validation error) — drives the ConnectionLostView recovery UI.
    var isConnectionError = false

    /// Set when an unauthenticated free ATS check completes.
    private(set) var atsResult: ATSScoreResult?
    var isRunningFreeATS = false
    /// True while the résumé upload is on the wire. Home's check screen ends its
    /// "Reading your résumé" stage when this turns false.
    private(set) var isUploadingResume = false

    /// The inputs `atsResult` was computed from. Always written together with
    /// `atsResult` so that a diagnosis can never outlive the inputs it describes.
    private(set) var guestDiagnosisFingerprint: GuestDiagnosisContinuity.InputFingerprint?

    /// True when a guest diagnosis is still valid for the inputs on screen —
    /// including after signing in.
    var hasCarriedGuestDiagnosis: Bool {
        atsResult != nil && guestDiagnosisFingerprint != nil
    }

    /// Set after a successful upload, and cleared immediately.
    ///
    /// This used to raise a "Save this resume?" confirmation dialog, removed on
    /// 2026-07-27 because it interrupted the user mid-result to ask something
    /// the page already offers further down. The property is kept because
    /// several call sites still set it; nothing consumes it as a prompt.
    var pendingSaveResumeId: String?

    /// Uploads a résumé file with its job and returns the server's ids. Injected in tests.
    typealias ResumeUploader = @MainActor (
        _ fileURL: URL,
        _ jobDescription: String?,
        _ jobDescriptionURL: String?,
        _ token: String
    ) async throws -> ResumeUploadResponse

    private let apiClient = RuntimeServices.sharedAPIClient
    private let optimizationService: any ResumeOptimizationServiceProtocol
    private let uploader: ResumeUploader
    /// Analytics sink, injected in tests. Production sends to PostHog.
    private let track: @MainActor (AnalyticsEvent) -> Void
    private var uploadContextSignature: String?
    /// Whose upload `uploadResponse` is. The server reads résumés through the
    /// user's own RLS client, so an upload made by one identity (a guest's
    /// anonymous user) is invisible to another (the account they then sign in
    /// to), and `/api/optimize` answers "Resume not found" (founder, device
    /// test 2026-10-21). An upload is reused only by the identity that made it.
    private var uploadIdentity: String?

    init(
        optimizationService: any ResumeOptimizationServiceProtocol = RuntimeServices.resumeOptimizationService(),
        uploader: ResumeUploader? = nil,
        track: (@MainActor (AnalyticsEvent) -> Void)? = nil
    ) {
        self.optimizationService = optimizationService
        self.track = track ?? { AnalyticsService.shared.track($0) }
        self.uploader = uploader ?? { fileURL, jobDescription, jobDescriptionURL, token in
            try await RuntimeServices.sharedAPIClient.uploadResume(
                fileURL: fileURL,
                jobDescription: jobDescription,
                jobDescriptionURL: jobDescriptionURL,
                token: token,
                deferOptimization: true
            )
        }
    }

    /// The identity an upload belongs to: the Supabase user id (an anonymous
    /// guest has one too), or `guest` with no session.
    static func uploadIdentity(for session: AuthSession?) -> String {
        guard let userId = session?.userId.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else { return "guest" }
        return "user:\(userId)"
    }

    /// Forgets the uploaded résumé and job ids. Called when the signed-in
    /// identity changes (sign-in, sign-out, account deletion), so no id made by
    /// one identity is sent by another. The picked file and job text stay.
    func resetUploadCache() {
        uploadResponse = nil
        uploadContextSignature = nil
        uploadIdentity = nil
        pendingSaveResumeId = nil
    }

    /// True for the server's answer when the ids sent no longer resolve for this
    /// user: a résumé or job uploaded by another identity, or deleted. It arrives
    /// as a 500 (or 404) whose `error` is "Resume not found" or
    /// "Job description not found" (web `src/app/api/optimize/route.ts`).
    static func isUploadedIdNotFound(_ error: Error) -> Bool {
        guard case .serverError(let status, let message)? = error as? APIClientError,
              status == 404 || status == 500 else { return false }
        let lower = message.lowercased()
        return lower.contains("resume not found") || lower.contains("job description not found")
    }

    /// Copies the picked PDF into the sandbox temp dir and sets the URL + name.
    func cachePickedFile(url: URL, source: String = "unknown") {
        let filename = url.lastPathComponent
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension.lowercased()
        let dest = docs.appendingPathComponent("picked_resume.\(ext)")

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)

        let candidateURL = FileManager.default.fileExists(atPath: dest.path) ? dest : url
        do {
            _ = try UploadFilePreflight.loadResumeFile(candidateURL)
        } catch {
            selectedResumeURL = nil
            selectedResumeName = nil
            failedResumeName = filename
            let reason = UploadFailureReason(error: error)
            uploadFailureReason = reason
            errorMessage = error.localizedDescription
            track(.resumeUploadPreflightRejected(reason: reason.analyticsValue))
            return
        }
        selectedResumeURL = candidateURL
        selectedResumeName = filename
        failedResumeName = nil
        uploadFailureReason = nil
        errorMessage = nil
        let pickedType = url.pathExtension.isEmpty ? "unknown" : url.pathExtension.lowercased()
        track(.resumeFileSelected(
            source: source,
            fileType: pickedType,
            sizeBucket: Self.fileSizeBucket(for: candidateURL)
        ))
    }

    /// The résumé held right now, described the PII-safe way the upload events
    /// describe a selection: file type and coarse size bucket, never a name.
    ///
    /// `("none", "none")` when nothing is selected. The picker events carry this
    /// so an opened-then-cancelled picker can be read as either a genuine
    /// drop-off (empty-handed both sides) or an abandoned replacement.
    var heldResume: (fileType: String, sizeBucket: String) {
        Self.heldResumeDescriptor(for: selectedResumeURL)
    }

    static func heldResumeDescriptor(for url: URL?) -> (fileType: String, sizeBucket: String) {
        guard let url else { return ("none", "none") }
        let ext = url.pathExtension.isEmpty ? "unknown" : url.pathExtension.lowercased()
        return (ext, fileSizeBucket(for: url))
    }

    /// PII-safe coarse file-size bucket for upload analytics.
    static func fileSizeBucket(for url: URL) -> String {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? -1
        switch bytes {
        case 0..<100_000: return "<100kb"
        case 100_000..<1_000_000: return "100kb-1mb"
        case 1_000_000..<5_000_000: return "1mb-5mb"
        case 5_000_000...: return ">5mb"
        default: return "unknown"
        }
    }

    /// Pre-fills Step 1 from a file URL already downloaded from the library.
    func useLibraryResume(localURL: URL, displayName: String) {
        selectedResumeURL = localURL
        selectedResumeName = displayName
    }

    /// Starts a fresh job match without discarding the résumé or the previous
    /// optimization stored in AppState. Every value cleared here was produced
    /// from the old target job and must not leak into the next analysis.
    func prepareForAnotherJob() {
        jobDescriptionURL = ""
        jobDescription = ""
        reviewId = nil
        optimizationId = nil
        uploadResponse = nil
        errorMessage = nil
        uploadFailureReason = nil
        failedResumeName = nil
        isConnectionError = false
        atsResult = nil
        guestDiagnosisFingerprint = nil
        pendingSaveResumeId = nil
        uploadContextSignature = nil
        uploadIdentity = nil
    }

    /// Uploads the résumé and job, or reuses the last upload when the file, the
    /// job and the identity are all unchanged. `forceFresh` skips the reuse.
    func ensureUploadedResumeForCurrentJob(
        appState: AppState,
        forceFresh: Bool = false
    ) async throws -> ResumeUploadResponse? {
        guard let selectedResumeURL else {
            errorMessage = NSLocalizedString("Choose a PDF resume first.", comment: "")
            return nil
        }

        let jobInput = JobInputPolicy.evaluate(description: jobDescription, urlString: jobDescriptionURL)
        let currentUploadSignature = [
            selectedResumeURL.path,
            jobInput.normalizedDescription ?? "",
            jobInput.normalizedURL ?? "",
        ].joined(separator: "\u{1F}")
        guard jobInput.isReady else {
            errorMessage = jobInput.validationMessage
            return nil
        }

        guard appState.session?.accessToken != nil else {
            errorMessage = NSLocalizedString("Please sign in first.", comment: "")
            return nil
        }

        let currentIdentity = Self.uploadIdentity(for: appState.session)
        if !forceFresh,
           let upload = uploadResponse,
           uploadContextSignature == currentUploadSignature,
           uploadIdentity == currentIdentity,
           upload.resumeId?.isEmpty == false,
           upload.jobDescriptionId?.isEmpty == false {
            return upload
        }

        let uploadFileType = selectedResumeURL.pathExtension.isEmpty ? "unknown" : selectedResumeURL.pathExtension.lowercased()
        track(.resumeUploadStarted(fileType: uploadFileType))

        isUploadingResume = true
        defer { isUploadingResume = false }
        let upload = try await appState.callWithFreshToken { token in
            try await self.uploader(
                selectedResumeURL,
                jobInput.normalizedDescription,
                jobInput.normalizedURL,
                token
            )
        }
        uploadResponse = upload
        uploadContextSignature = currentUploadSignature
        uploadIdentity = currentIdentity
        track(.resumeUploadSucceeded(fileType: uploadFileType))
        #if DEBUG
        print("🔧 [TAILOR] upload → resumeId=\(upload.resumeId ?? "nil") jdId=\(upload.jobDescriptionId ?? "nil")")
        #endif

        return upload
    }

    func optimize(appState: AppState) async {
        guard selectedResumeURL != nil else {
            errorMessage = NSLocalizedString("Choose a PDF resume first.", comment: "")
            return
        }

        let jobInput = JobInputPolicy.evaluate(description: jobDescription, urlString: jobDescriptionURL)
        guard jobInput.isReady else {
            errorMessage = jobInput.validationMessage
            return
        }

        guard appState.session?.accessToken != nil else {
            errorMessage = NSLocalizedString("Please sign in first.", comment: "")
            return
        }

        isOptimizing = true
        errorMessage = nil
        isConnectionError = false
        reviewId = nil
        optimizationId = nil
        defer { isOptimizing = false }

        // False until this run has an upload in hand. A cached upload from
        // another identity or job is replaced, and that upload can fail; its
        // failure must reach the funnel (Codex P2 on PR #202).
        var didUpload = false

        do {
            guard let upload = try await ensureUploadedResumeForCurrentJob(appState: appState) else { return }
            didUpload = true

            // Some backends return reviewId straight from upload — short-circuit.
            // No optimize call ran, so there is no fit measurement to show.
            if let reviewId = upload.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
                self.fitPreview = nil
                return
            }

            guard let resumeId = upload.resumeId, !resumeId.isEmpty,
                  let jobDescriptionId = upload.jobDescriptionId, !jobDescriptionId.isEmpty else {
                errorMessage = upload.error ?? NSLocalizedString("Upload did not return resume or job description ids.", comment: "")
                return
            }

            // Step 2: actually run the optimizer.
            let optimize: OptimizeResponse
            do {
                optimize = try await runOptimizer(resumeId: resumeId, jobDescriptionId: jobDescriptionId, appState: appState)
            } catch where Self.isUploadedIdNotFound(error) {
                // The server cannot see these ids for this user (an upload made by
                // another identity, or deleted). Upload once more and retry once.
                // A second "not found" goes to the normal error path below.
                resetUploadCache()
                // This upload can fail on its own; its failure is an upload
                // failure and must reach the funnel (Codex on PR #202).
                didUpload = false
                guard let fresh = try await ensureUploadedResumeForCurrentJob(appState: appState, forceFresh: true),
                      let freshResumeId = fresh.resumeId, !freshResumeId.isEmpty,
                      let freshJobId = fresh.jobDescriptionId, !freshJobId.isEmpty else {
                    if errorMessage == nil {
                        errorMessage = NSLocalizedString("Upload did not return resume or job description ids.", comment: "")
                    }
                    return
                }
                didUpload = true
                optimize = try await runOptimizer(resumeId: freshResumeId, jobDescriptionId: freshJobId, appState: appState)
            }

            #if DEBUG
            print("🔍 [TAILOR] optimize response: reviewId=\(optimize.reviewId ?? "nil") optimizationId=\(optimize.optimizationId ?? "nil") sections=\(optimize.sections?.count ?? 0) error=\(optimize.error ?? "none")")
            #endif
            // Capture the fit check BEFORE routing. The review-based flow
            // returns a reviewId, and this branch used to win and return, so
            // the app went straight to the accept screen and the fit check was
            // never shown (founder, device test 2026-07-26).
            self.fitPreview = optimize.fit

            if let reviewId = optimize.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
                #if DEBUG
                print("✅ [TAILOR] → reviewId set: \(reviewId)")
                #endif
            } else if let optId = optimize.optimizationId, !optId.isEmpty {
                self.optimizationId = optId
                pendingSaveResumeId = optId
                #if DEBUG
                print("✅ [TAILOR] → optimizationId set: \(optId)")
                #endif
                track(
                    .optimizationCompleted(optimizationId: optId, reviewId: nil, path: .direct)
                )
            } else {
                #if DEBUG
                print("❌ [TAILOR] → no valid id in response")
                #endif
                errorMessage = optimize.error ?? NSLocalizedString("Optimization did not return a result. Try again.", comment: "")
            }
        } catch where Self.isCancellation(error) {
            // The user cancelled the check. Nothing failed, so nothing is reported.
            return
        } catch let apiError as APIClientError {
            if case .serverError(let status, let message) = apiError {
                errorMessage = status == 400 ? JobInputPolicy.friendlyInputError() : enhancedError(message)
                if !didUpload {
                    track(.resumeUploadFailed(failureStage: "upload", errorCode: "\(status)"))
                }
            } else {
                errorMessage = apiError.localizedDescription
                if !didUpload {
                    track(.resumeUploadFailed(failureStage: "upload", errorCode: "client_error"))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isConnectionError = Self.isConnectivityError(error)
            if !didUpload {
                track(.resumeUploadFailed(failureStage: "upload", errorCode: "unknown"))
            }
        }
    }

    private func runOptimizer(
        resumeId: String,
        jobDescriptionId: String,
        appState: AppState
    ) async throws -> OptimizeResponse {
        track(.optimizationStarted(
            resumeId: resumeId,
            jobDescriptionId: jobDescriptionId,
            hasURL: !jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasPaste: !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ))
        return try await appState.callWithFreshToken { token in
            try await self.optimizationService.optimize(
                resumeId: resumeId,
                jobDescriptionId: jobDescriptionId,
                token: token
            )
        }
    }

    /// A request stopped because its task was cancelled (Cancel on Home's check
    /// screen), not because anything went wrong.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        return (error as? URLError)?.code == .cancelled
    }

    static func isConnectivityError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .dataNotAllowed, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }

    func runFreeATS(appState: AppState) async {
        guard let selectedResumeURL else {
            errorMessage = NSLocalizedString("Choose a PDF resume first.", comment: "")
            return
        }
        let jobInput = JobInputPolicy.evaluate(description: jobDescription, urlString: jobDescriptionURL, destination: .publicCheck)
        guard jobInput.isReady else {
            errorMessage = jobInput.validationMessage
            return
        }
        isRunningFreeATS = true
        errorMessage = nil
        isConnectionError = false
        atsResult = nil
        guestDiagnosisFingerprint = nil
        defer { isRunningFreeATS = false }
        do {
            let response = try await apiClient.runPublicATSCheck(
                resumeURL: selectedResumeURL,
                jobDescription: jobInput.normalizedDescription,
                jobDescriptionURL: jobInput.normalizedURL,
                sessionId: appState.anonymousATSSessionId
            )
            // A result that lands after Cancel is not shown: the user left the check.
            guard !Task.isCancelled else { return }
            recordGuestDiagnosis(response)
            appState.storeAnonymousATSSessionId(response.sessionId)
        } catch where Self.isCancellation(error) {
            return
        } catch let apiError as APIClientError {
            if case .serverError(let status, _) = apiError, status == 400 {
                errorMessage = JobInputPolicy.friendlyInputError()
            } else {
                errorMessage = apiError.userFacingMessage
            }
            isConnectionError = false
        } catch {
            errorMessage = error.localizedDescription
            isConnectionError = Self.isConnectivityError(error)
        }
    }

    /// Records a completed diagnosis together with the inputs it describes, so the
    /// two can never drift apart.
    func recordGuestDiagnosis(_ result: ATSScoreResult) {
        atsResult = result
        guestDiagnosisFingerprint = currentInputFingerprint()
    }

    /// Drops the guest diagnosis only when the inputs it was computed from have
    /// changed. Safe to call on every authentication transition: signing in and
    /// cancelling sign-in both leave the inputs alone, so both preserve the result.
    func invalidateGuestDiagnosisIfInputsChanged() {
        switch GuestDiagnosisContinuity.decide(
            capturedAt: guestDiagnosisFingerprint,
            current: currentInputFingerprint()
        ) {
        case .carryForward, .noDiagnosis:
            return
        case .invalidateDiagnosis:
            atsResult = nil
            guestDiagnosisFingerprint = nil
        }
    }

    /// The step Home offers once authenticated — never an automatic optimization.
    var postAuthStep: GuestDiagnosisContinuity.PostAuthStep {
        GuestDiagnosisContinuity.postAuthStep(
            for: GuestDiagnosisContinuity.decide(
                capturedAt: guestDiagnosisFingerprint,
                current: currentInputFingerprint()
            )
        )
    }

    private func currentInputFingerprint() -> GuestDiagnosisContinuity.InputFingerprint? {
        GuestDiagnosisContinuity.InputFingerprint.make(
            resumeURL: selectedResumeURL,
            description: jobDescription,
            urlString: jobDescriptionURL
        )
    }

    func useSharedJobURLIfNeeded(from appState: AppState) {
        guard jobDescriptionURL.isEmpty, let sharedURL = appState.pendingSharedJobURL else { return }
        jobDescriptionURL = sharedURL.absoluteString
        appState.clearPendingSharedJobURL()
    }

    private func enhancedError(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("function_invocation_timeout") || lower.contains("timed out") || lower.contains("timeout") {
            return NSLocalizedString("The optimizer took too long to read the job post. LinkedIn pages can block or delay scraping.\n\nPaste the job description text into Step 2 and run Optimize again.", comment: "")
        }
        guard lower.contains("read") && lower.contains("pdf") else { return message }
        return message + NSLocalizedString("\n\nTip: Upload a freshly exported, text-based PDF from Files. Scanned/image-only PDFs often cannot be read by the optimizer.", comment: "")
    }
}
