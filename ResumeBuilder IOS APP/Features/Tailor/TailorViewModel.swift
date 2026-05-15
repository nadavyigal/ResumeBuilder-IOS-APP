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

    // Shared with ScanViewModel so a pick from either tab is visible in both.
    private static let filenameKey = "savedResumeFilename"
    private static let pathKey     = "savedResumeLocalPath"

    private let apiClient = APIClient()
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService()
            : ResumeOptimizationService()
    ) {
        self.optimizationService = optimizationService
    }

    /// Name of the locally cached resume, if one exists on disk.
    var cachedResumeName: String? {
        guard let name = UserDefaults.standard.string(forKey: Self.filenameKey),
              let path = UserDefaults.standard.string(forKey: Self.pathKey),
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return name
    }

    /// Pre-fills Step 1 from the cached PDF. Returns `true` on success.
    @discardableResult
    func useCachedResume() -> Bool {
        guard let name = UserDefaults.standard.string(forKey: Self.filenameKey),
              let path = UserDefaults.standard.string(forKey: Self.pathKey),
              FileManager.default.fileExists(atPath: path) else {
            return false
        }
        selectedResumeURL = URL(fileURLWithPath: path)
        selectedResumeName = name
        return true
    }

    /// Saves the picked file into the sandbox cache so it can be reused next session.
    func cachePickedFile(url: URL) {
        let filename = url.lastPathComponent
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("cached_resume.pdf")

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)

        if FileManager.default.fileExists(atPath: dest.path) {
            UserDefaults.standard.set(filename, forKey: Self.filenameKey)
            UserDefaults.standard.set(dest.path, forKey: Self.pathKey)
            selectedResumeURL = dest
        } else {
            selectedResumeURL = url
        }
        selectedResumeName = filename
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
}
