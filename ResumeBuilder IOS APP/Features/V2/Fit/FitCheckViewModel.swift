import Foundation
import Observation

@Observable
@MainActor
final class FitCheckViewModel {
    var jobDescription = ""
    var isLoading = false
    var result: FitCheckResult?
    var errorMessage: String?

    /// The resume PDF the user has already selected upstream (set by the presenting view).
    var resumeURL: URL?

    /// Called when the user taps "Optimize for this job" in the verdict.
    var onOptimize: ((String) -> Void)?
    /// Called when the user taps "Skip" or dismisses the verdict.
    var onSkip: (() -> Void)?
    /// Called when no active resume is available — route to upload.
    var onNeedResume: (() -> Void)?

    private let fitCheckService: any FitCheckServiceProtocol

    init(fitCheckService: any FitCheckServiceProtocol = RuntimeServices.fitCheckService()) {
        self.fitCheckService = fitCheckService
    }

    var isInVerdictState: Bool { result != nil }

    var canCheck: Bool {
        let trimmed = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").count >= 50
    }

    var jobDescriptionTooShort: Bool {
        let trimmed = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !canCheck
    }

    func checkFit() async {
        guard let resumeURL else {
            onNeedResume?()
            return
        }

        let trimmed = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.split(separator: " ").count >= 50 else {
            errorMessage = NSLocalizedString(
                "Paste the full job description (at least 100 words) so we can check your fit accurately.",
                comment: ""
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AnalyticsService.shared.track(.fitCheckStarted)

        do {
            let checkResult = try await fitCheckService.checkFit(
                resumeURL: resumeURL,
                jobDescription: trimmed,
                jobDescriptionURL: nil,
                sessionId: nil
            )
            result = checkResult
            AnalyticsService.shared.track(
                .fitCheckCompleted(
                    verdict: checkResult.verdict.band.rawValue,
                    matchScore: checkResult.verdict.score
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func optimizeForThisJob() {
        guard let result else { return }
        AnalyticsService.shared.track(.fitCheckOptimizeTapped)
        let jd = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        onOptimize?(jd)
    }

    func skip() {
        AnalyticsService.shared.track(.fitCheckSkipped)
        onSkip?()
    }

    func resetToEntry() {
        result = nil
        errorMessage = nil
    }
}
