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

    /// Set when an unauthenticated free ATS check completes.
    var atsResult: ATSScoreResult?
    var isRunningFreeATS = false

    /// Set after a successful upload — triggers the "Save this resume?" prompt.
    /// Cleared after the user responds.
    var pendingSaveResumeId: String?

    private let apiClient = APIClient()
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        optimizationService: any ResumeOptimizationServiceProtocol = RuntimeServices.resumeOptimizationService()
    ) {
        self.optimizationService = optimizationService
    }

    /// Copies the picked PDF into the sandbox temp dir and sets the URL + name.
    func cachePickedFile(url: URL) {
        let filename = url.lastPathComponent
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("picked_resume.pdf")

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
            errorMessage = error.localizedDescription
            return
        }
        selectedResumeURL = candidateURL
        selectedResumeName = filename
        errorMessage = nil
    }

    /// Pre-fills Step 1 from a file URL already downloaded from the library.
    func useLibraryResume(localURL: URL, displayName: String) {
        selectedResumeURL = localURL
        selectedResumeName = displayName
    }

    func optimize(appState: AppState) async {
        guard let selectedResumeURL else {
            errorMessage = "Choose a PDF resume first."
            return
        }

        let trimmedDescription = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty || !trimmedURL.isEmpty else {
            errorMessage = "Paste a job description or add a job link."
            return
        }

        guard appState.session?.accessToken != nil else {
            errorMessage = "Please sign in first."
            return
        }

        isOptimizing = true
        errorMessage = nil
        reviewId = nil
        optimizationId = nil
        defer { isOptimizing = false }

        let analyticsId = appState.session?.userId ?? "anonymous"
        AnalyticsService.shared.captureUploadResumeStarted(
            distinctId: analyticsId,
            hasJobURL: !trimmedURL.isEmpty
        )

        do {
            // Step 1 — upload PDF + job context. Server stores resume and JD,
            // returns ids we need for the optimize call.
            let upload = try await appState.callWithFreshToken { token in
                try await self.apiClient.uploadResume(
                    fileURL: selectedResumeURL,
                    jobDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    jobDescriptionURL: trimmedURL.isEmpty ? nil : trimmedURL,
                    token: token,
                    deferOptimization: true
                )
            }
            uploadResponse = upload
            print("🔧 [TAILOR] upload → resumeId=\(upload.resumeId ?? "nil") jdId=\(upload.jobDescriptionId ?? "nil")")

            // Offer to save the uploaded resume to the library (prompt shown in TailorView).
            if let resumeId = upload.resumeId, !resumeId.isEmpty {
                pendingSaveResumeId = resumeId
            }

            // Some backends return reviewId straight from upload — short-circuit.
            if let reviewId = upload.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
                return
            }

            guard let resumeId = upload.resumeId, !resumeId.isEmpty,
                  let jobDescriptionId = upload.jobDescriptionId, !jobDescriptionId.isEmpty else {
                errorMessage = upload.error ?? "Upload did not return resume or job description ids."
                return
            }

            // Step 2 — actually run the optimizer.
            let optimize = try await appState.callWithFreshToken { token in
                try await self.optimizationService.optimize(
                    resumeId: resumeId,
                    jobDescriptionId: jobDescriptionId,
                    token: token
                )
            }

            print("🔍 [TAILOR] optimize response: reviewId=\(optimize.reviewId ?? "nil") optimizationId=\(optimize.optimizationId ?? "nil") sections=\(optimize.sections?.count ?? 0) error=\(optimize.error ?? "none")")
            if let reviewId = optimize.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
                print("✅ [TAILOR] → reviewId set: \(reviewId)")
            } else if let optId = optimize.optimizationId, !optId.isEmpty {
                self.optimizationId = optId
                print("✅ [TAILOR] → optimizationId set: \(optId)")
                AnalyticsService.shared.captureOptimizationCompleted(
                    distinctId: analyticsId,
                    optimizationId: optId
                )
            } else {
                print("❌ [TAILOR] → no valid id in response")
                errorMessage = optimize.error ?? "Optimization did not return a result. Try again."
            }
        } catch let apiError as APIClientError {
            if case .serverError(_, let message) = apiError {
                errorMessage = enhancedError(message)
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runFreeATS(appState: AppState) async {
        guard let selectedResumeURL else {
            errorMessage = "Choose a PDF resume first."
            return
        }
        let trimmedDescription = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty || !trimmedURL.isEmpty else {
            errorMessage = "Paste a job description or add a job link."
            return
        }
        isRunningFreeATS = true
        errorMessage = nil
        atsResult = nil
        defer { isRunningFreeATS = false }
        do {
            let response = try await apiClient.runPublicATSCheck(
                resumeURL: selectedResumeURL,
                jobDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
                jobDescriptionURL: trimmedURL.isEmpty ? nil : trimmedURL,
                sessionId: appState.anonymousATSSessionId
            )
            atsResult = response
            appState.storeAnonymousATSSessionId(response.sessionId)
        } catch {
            errorMessage = error.localizedDescription
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
            return "The optimizer took too long to read the job post. LinkedIn pages can block or delay scraping.\n\nPaste the job description text into Step 2 and run Optimize again."
        }
        guard lower.contains("read") && lower.contains("pdf") else { return message }
        return message + "\n\nTip: Upload a freshly exported, text-based PDF from Files. Scanned/image-only PDFs often cannot be read by the optimizer."
    }
}
