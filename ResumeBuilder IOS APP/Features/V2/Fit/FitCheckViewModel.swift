import Foundation
import Observation

@Observable
@MainActor
final class FitCheckViewModel {
    var jobDescription = ""
    var jobDescriptionURL = ""
    var isLoading = false
    var result: FitCheckResult?
    var errorMessage: String?

    /// The server-side resume id already produced by the upload/library flow.
    var resumeId: String?

    /// Bearer token for the authenticated resume-id Fit check.
    var accessToken: String?

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

    /// Set while the user is deliberately changing the target job.
    private(set) var isEditingTarget = false

    /// Guards the automatic run so continuing into Fit checks the carried job once,
    /// not on every re-render.
    private(set) var hasAttemptedCarriedCheck = false

    /// What the Fit surface should show right now.
    var continuationStep: FitContinuation.Step {
        FitContinuation.step(
            carriedJobIsReady: canCheck,
            hasVerdict: result != nil,
            hasFailed: errorMessage != nil,
            isEditingTarget: isEditingTarget
        )
    }

    var jobInputEvaluation: JobInputPolicy.Evaluation {
        JobInputPolicy.evaluate(description: jobDescription, urlString: jobDescriptionURL)
    }

    var canCheck: Bool {
        jobInputEvaluation.isReady
    }

    var jobDescriptionTooShort: Bool {
        jobInputEvaluation.blockingReason == .descriptionTooShort
    }

    func checkFit() async {
        guard let resumeId, !resumeId.isEmpty else {
            onNeedResume?()
            return
        }

        guard let accessToken, !accessToken.isEmpty else {
            errorMessage = NSLocalizedString("Please sign in first.", comment: "")
            return
        }

        let evaluation = jobInputEvaluation
        guard evaluation.isReady else {
            errorMessage = evaluation.validationMessage
            if let reason = evaluation.blockingReason?.analyticsValue {
                AnalyticsService.shared.track(.jobInputValidationShown(surface: "fit", reason: reason))
            }
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AnalyticsService.shared.track(.fitCheckStarted)

        do {
            let checkResult = try await fitCheckService.checkFit(
                resumeId: resumeId,
                jobDescription: evaluation.normalizedDescription,
                jobDescriptionURL: evaluation.normalizedURL,
                accessToken: accessToken,
                sessionId: nil
            )
            result = checkResult
            AnalyticsService.shared.track(
                .fitCheckCompleted(
                    verdict: checkResult.verdict.band.rawValue,
                    matchScore: checkResult.verdict.score
                )
            )
        } catch let apiError as APIClientError {
            if case .serverError(let status, _) = apiError, status == 400 {
                errorMessage = JobInputPolicy.friendlyInputError()
            } else {
                errorMessage = apiError.userFacingMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func optimizeForThisJob() {
        guard result != nil else { return }
        AnalyticsService.shared.track(.fitCheckOptimizeTapped)
        let jd = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        onOptimize?(jd)
    }

    func skip() {
        AnalyticsService.shared.track(.fitCheckSkipped)
        onSkip?()
    }

    /// Continues the journey into Fit: checks the job carried from Home directly
    /// instead of asking the user to confirm it in a second form. Does nothing when
    /// no usable job was carried, or once the carried target has already been checked.
    func beginCarriedFitCheck() async {
        guard !hasAttemptedCarriedCheck else { return }
        guard continuationStep == .runAutomatically else { return }
        hasAttemptedCarriedCheck = true
        await checkFit()
    }

    /// Lets the user change the target job at any point before optimizing.
    /// Clears any stale verdict/failure so the next check describes the new target.
    func editTarget() {
        isEditingTarget = true
        result = nil
        errorMessage = nil
    }

    /// Re-checks Fit against the edited target.
    func applyEditedTarget() async {
        isEditingTarget = false
        hasAttemptedCarriedCheck = true
        await checkFit()
    }

    func resetToEntry() {
        result = nil
        errorMessage = nil
        isEditingTarget = false
        hasAttemptedCarriedCheck = false
    }
}
