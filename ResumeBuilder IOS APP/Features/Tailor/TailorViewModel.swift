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
    var atsResult: ATSScoreResult?
    var isRunningFreeATS = false

    /// Set after a successful upload — triggers the "Save this resume?" prompt.
    /// Cleared after the user responds.
    var pendingSaveResumeId: String?

    private let apiClient = RuntimeServices.sharedAPIClient
    private let optimizationService: any ResumeOptimizationServiceProtocol
    private var uploadContextSignature: String?

    init(
        optimizationService: any ResumeOptimizationServiceProtocol = RuntimeServices.resumeOptimizationService()
    ) {
        self.optimizationService = optimizationService
    }

    /// Copies the picked PDF into the sandbox temp dir and sets the URL + name.
    func cachePickedFile(url: URL) {
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
            AnalyticsService.shared.track(.resumeUploadPreflightRejected(reason: reason.analyticsValue))
            return
        }
        selectedResumeURL = candidateURL
        selectedResumeName = filename
        failedResumeName = nil
        uploadFailureReason = nil
        errorMessage = nil
        let pickedType = url.pathExtension.isEmpty ? "unknown" : url.pathExtension.lowercased()
        AnalyticsService.shared.track(.resumeFileSelected(
            fileType: pickedType,
            sizeBucket: Self.fileSizeBucket(for: candidateURL)
        ))
    }

    /// PII-safe coarse file-size bucket for upload analytics.
    private static func fileSizeBucket(for url: URL) -> String {
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

    func ensureUploadedResumeForCurrentJob(appState: AppState) async throws -> ResumeUploadResponse? {
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

        if let upload = uploadResponse,
           uploadContextSignature == currentUploadSignature,
           upload.resumeId?.isEmpty == false,
           upload.jobDescriptionId?.isEmpty == false {
            return upload
        }

        let uploadFileType = selectedResumeURL.pathExtension.isEmpty ? "unknown" : selectedResumeURL.pathExtension.lowercased()
        AnalyticsService.shared.track(.resumeUploadStarted(fileType: uploadFileType))

        let upload = try await appState.callWithFreshToken { token in
            try await self.apiClient.uploadResume(
                fileURL: selectedResumeURL,
                jobDescription: jobInput.normalizedDescription,
                jobDescriptionURL: jobInput.normalizedURL,
                token: token,
                deferOptimization: true
            )
        }
        uploadResponse = upload
        uploadContextSignature = currentUploadSignature
        AnalyticsService.shared.track(.resumeUploadSucceeded(fileType: uploadFileType))
        #if DEBUG
        print("🔧 [TAILOR] upload → resumeId=\(upload.resumeId ?? "nil") jdId=\(upload.jobDescriptionId ?? "nil")")
        #endif

        let fileExt = selectedResumeURL.pathExtension.lowercased()
        let fileType = fileExt.isEmpty ? "unknown" : fileExt
        AnalyticsService.shared.track(.resumeUploaded(fileType: fileType))

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

        var didUpload = uploadResponse?.resumeId?.isEmpty == false

        do {
            guard let upload = try await ensureUploadedResumeForCurrentJob(appState: appState) else { return }
            didUpload = true

            // Some backends return reviewId straight from upload — short-circuit.
            if let reviewId = upload.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
                return
            }

            guard let resumeId = upload.resumeId, !resumeId.isEmpty,
                  let jobDescriptionId = upload.jobDescriptionId, !jobDescriptionId.isEmpty else {
                errorMessage = upload.error ?? NSLocalizedString("Upload did not return resume or job description ids.", comment: "")
                return
            }

            // Step 2 — actually run the optimizer.
            AnalyticsService.shared.track(.optimizationStarted(resumeId: resumeId, jobDescriptionId: jobDescriptionId))
            let optimize = try await appState.callWithFreshToken { token in
                try await self.optimizationService.optimize(
                    resumeId: resumeId,
                    jobDescriptionId: jobDescriptionId,
                    token: token
                )
            }

            #if DEBUG
            print("🔍 [TAILOR] optimize response: reviewId=\(optimize.reviewId ?? "nil") optimizationId=\(optimize.optimizationId ?? "nil") sections=\(optimize.sections?.count ?? 0) error=\(optimize.error ?? "none")")
            #endif
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
                AnalyticsService.shared.track(.optimizationCompleted(optimizationId: optId, reviewId: nil))
            } else {
                #if DEBUG
                print("❌ [TAILOR] → no valid id in response")
                #endif
                errorMessage = optimize.error ?? NSLocalizedString("Optimization did not return a result. Try again.", comment: "")
            }
        } catch let apiError as APIClientError {
            if case .serverError(let status, let message) = apiError {
                errorMessage = status == 400 ? JobInputPolicy.friendlyInputError() : enhancedError(message)
                if !didUpload {
                    AnalyticsService.shared.track(.resumeUploadFailed(failureStage: "upload", errorCode: "\(status)"))
                }
            } else {
                errorMessage = apiError.localizedDescription
                if !didUpload {
                    AnalyticsService.shared.track(.resumeUploadFailed(failureStage: "upload", errorCode: "client_error"))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isConnectionError = Self.isConnectivityError(error)
            if !didUpload {
                AnalyticsService.shared.track(.resumeUploadFailed(failureStage: "upload", errorCode: "unknown"))
            }
        }
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
        let jobInput = JobInputPolicy.evaluate(description: jobDescription, urlString: jobDescriptionURL)
        guard jobInput.isReady else {
            errorMessage = jobInput.validationMessage
            return
        }
        isRunningFreeATS = true
        errorMessage = nil
        isConnectionError = false
        atsResult = nil
        defer { isRunningFreeATS = false }
        do {
            let response = try await apiClient.runPublicATSCheck(
                resumeURL: selectedResumeURL,
                jobDescription: jobInput.normalizedDescription,
                jobDescriptionURL: jobInput.normalizedURL,
                sessionId: appState.anonymousATSSessionId
            )
            atsResult = response
            appState.storeAnonymousATSSessionId(response.sessionId)
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
