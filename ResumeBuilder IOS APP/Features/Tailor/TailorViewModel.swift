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

    private let apiClient = APIClient()
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService()
            : ResumeOptimizationService()
    ) {
        self.optimizationService = optimizationService
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

        do {
            // Step 1 — upload PDF + job context. Server stores resume and JD,
            // returns ids we need for the optimize call.
            let upload = try await appState.callWithFreshToken { token in
                try await self.apiClient.uploadResume(
                    fileURL: selectedResumeURL,
                    jobDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    jobDescriptionURL: trimmedURL.isEmpty ? nil : trimmedURL,
                    token: token
                )
            }
            uploadResponse = upload

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

            if let reviewId = optimize.reviewId, !reviewId.isEmpty {
                self.reviewId = reviewId
            } else if let optId = optimize.optimizationId, !optId.isEmpty {
                self.optimizationId = optId
            } else {
                errorMessage = optimize.error ?? "Optimization did not return a result. Try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useSharedJobURLIfNeeded(from appState: AppState) {
        guard jobDescriptionURL.isEmpty, let sharedURL = appState.pendingSharedJobURL else { return }
        jobDescriptionURL = sharedURL.absoluteString
        appState.clearPendingSharedJobURL()
    }
}
