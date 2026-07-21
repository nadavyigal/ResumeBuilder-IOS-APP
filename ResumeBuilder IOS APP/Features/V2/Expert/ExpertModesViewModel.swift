import Foundation
import Observation

struct ExpertRunUIState: Equatable {
    let workflowType: ExpertWorkflowType
    let runId: String
    let status: String
    let output: JSONValue
    let missingEvidence: [String]
    let needsUserInput: Bool

    var report: ExpertReportDisplayModel? {
        ExpertReportParsing.displayModel(from: output)
    }

    var parsedOutput: ExpertOutputParsed {
        ExpertReportParsing.parsedOutput(from: output)
    }
}

enum ExpertCardPhase: Equatable {
    case idle
    case running
    case ready(ExpertRunUIState)
    case failed(String)
}

@Observable
@MainActor
final class ExpertModesViewModel {
    private(set) var phaseByType: [ExpertWorkflowType: ExpertCardPhase] = [:]
    private(set) var applyingWorkflow: ExpertWorkflowType?
    private(set) var toastMessage: String?
    var evidenceInputByType: [ExpertWorkflowType: String] = [:]
    private(set) var submittedEvidenceByType: [ExpertWorkflowType: String] = [:]

    var selectedVariantIndexByType: [ExpertWorkflowType: Int] = [:]

    private(set) var optimizationId: String
    /// When `nil` (e.g. opened from **Track**), apply still runs on the server but local resume sections are not merged.
    private let resumeViewModel: OptimizedResumeViewModel?
    private let service: ExpertWorkflowService

    // Saved reports from GET /applications/:id/expert-reports
    private(set) var savedReports: [ApplicationExpertReportItem] = []
    var applicationId: String? = nil

    private let trackingService = ApplicationTrackingService()
    private var savedReportsLoadedAt: Date?
    private var savedReportsInFlight: Task<Void, Never>?
    private static let savedReportsTTL: TimeInterval = 30

    init(
        optimizationId: String,
        resumeViewModel: OptimizedResumeViewModel?,
        applicationId: String? = nil,
        service: ExpertWorkflowService = ExpertWorkflowService()
    ) {
        self.optimizationId = optimizationId
        self.resumeViewModel = resumeViewModel
        self.applicationId = applicationId
        self.service = service
        for t in ExpertWorkflowType.allCases {
            phaseByType[t] = .idle
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    func loadSavedReports(token: String?) async {
        guard let appId = applicationId else { return }
        if let loadedAt = savedReportsLoadedAt,
           Date().timeIntervalSince(loadedAt) < Self.savedReportsTTL {
            return
        }
        if let savedReportsInFlight {
            await savedReportsInFlight.value
            return
        }
        let task = Task {
            do {
                savedReports = try await trackingService.fetchExpertReports(applicationId: appId, token: token)
                savedReportsLoadedAt = Date()
            } catch {
                // silently ignore — count already shown by ApplicationDetailViewModel
            }
        }
        savedReportsInFlight = task
        await task.value
        savedReportsInFlight = nil
    }

    func seedReadyPhase(workflowType: ExpertWorkflowType, snapshot: ExpertWorkflowRunSnapshot) {
        phaseByType[workflowType] = .ready(ExpertRunUIState(
            workflowType: workflowType,
            runId: snapshot.runId,
            status: snapshot.status,
            output: snapshot.output,
            missingEvidence: snapshot.missingEvidence,
            needsUserInput: snapshot.status == "needs_user_input"
        ))
    }

    func phase(for type: ExpertWorkflowType) -> ExpertCardPhase {
        phaseByType[type] ?? .idle
    }

    func evidenceText(for type: ExpertWorkflowType) -> String {
        evidenceInputByType[type] ?? ""
    }

    func setEvidenceText(_ text: String, for type: ExpertWorkflowType) {
        evidenceInputByType[type] = text
    }

    func selectedVariantIndex(for type: ExpertWorkflowType) -> Int? {
        selectedVariantIndexByType[type]
    }

    func setSelectedVariantIndex(_ index: Int, for type: ExpertWorkflowType) {
        selectedVariantIndexByType[type] = index
    }

    func run(_ type: ExpertWorkflowType, token: String?) async {
        phaseByType[type] = .running
        do {
            let evidenceText = evidenceText(for: type).trimmingCharacters(in: .whitespacesAndNewlines)
            let evidenceInputs: [String: JSONValue] = evidenceText.isEmpty
                ? [:]
                : ["user_context": .string(evidenceText)]
            let dto = try await service.run(
                type: type,
                optimizationId: optimizationId,
                token: token,
                evidenceInputs: evidenceInputs
            )
            submittedEvidenceByType[type] = evidenceText
            let state = ExpertRunUIState(
                workflowType: type,
                runId: dto.runId,
                status: dto.status,
                output: dto.output,
                missingEvidence: dto.missingEvidence ?? [],
                needsUserInput: dto.needsUserInput ?? (dto.status == "needs_user_input")
            )
            phaseByType[type] = .ready(state)
            initializeSelectionIfNeeded(for: type, parsedOutput: state.parsedOutput)
        } catch ExpertWorkflowServiceError.premiumRequired(let message) {
            phaseByType[type] = .failed(message)
        } catch {
            phaseByType[type] = .failed(error.localizedDescription)
        }
    }

    func apply(
        _ type: ExpertWorkflowType,
        token: String?,
        appState: AppState,
        selectedFields: [String]? = nil
    ) async {
        guard case .ready(let state) = phaseByType[type] else { return }
        applyingWorkflow = type
        defer { applyingWorkflow = nil }
        do {
            let selectionIndex: Int? = {
                guard type == .professionalSummaryLab || type == .coverLetterArchitect else { return nil }
                let count = type == .professionalSummaryLab
                    ? state.parsedOutput.summaryOptions.count
                    : state.parsedOutput.coverLetterVariants.count
                return clampedSelectionIndex(
                    selectedVariantIndexByType[type] ?? state.parsedOutput.recommendedIndex,
                    count: count
                ) ?? 0
            }()
            let screeningIndices: [Int]? = {
                guard type == .screeningAnswerStudio else { return nil }
                let count = state.parsedOutput.screeningAnswers.count
                return count > 0 ? Array(0..<count) : [0]
            }()
            let dto = try await service.apply(
                runId: state.runId,
                workflowType: type,
                token: token,
                selectionIndex: selectionIndex,
                screeningSelectedIndices: screeningIndices,
                selectedFields: selectedFields
            )
            if let resumeViewModel {
                resumeViewModel.mergeExpertApply(workflowType: type, output: state.output, applyResult: dto)
                resumeViewModel.applyExpertATSResult(dto)
                Task {
                    await resumeViewModel.forceReloadSections(appState: appState)
                }
                if type == .atsOptimizationReport {
                    Task {
                        await resumeViewModel.rescanATS(token: token)
                    }
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                appState.resumeSectionsNeedRefresh = true
                appState.resumePreviewRefreshToken += 1
            }

            let touchedResume = dto.updatedFields.contains(where: {
                $0.contains("summary")
                    || $0.contains("skills")
                    || $0.contains("experience")
                    || $0.contains("entire_resume")
            })
            let savedToApplication = await saveAppliedRunToApplicationIfPossible(runId: state.runId, token: token)
            if resumeViewModel == nil, dto.success != false, savedToApplication {
                toastMessage = String(format: NSLocalizedString("%@: applied and saved to this application.", comment: ""), type.displayTitle)
            } else if resumeViewModel == nil, dto.success != false {
                toastMessage = String(format: NSLocalizedString("%@: applied on server. Open Optimize to refresh resume text.", comment: ""), type.displayTitle)
            } else if !touchedResume, dto.success != false, savedToApplication {
                toastMessage = String(format: NSLocalizedString("%@: saved to Me → application assets.", comment: ""), type.displayTitle)
            } else if !touchedResume, dto.success != false {
                toastMessage = String(format: NSLocalizedString("%@: saved to this expert run. Open Expert from an application in Me to attach it there.", comment: ""), type.displayTitle)
            } else if dto.success != false, savedToApplication {
                toastMessage = String(format: NSLocalizedString("%@: changes applied and saved to this application.", comment: ""), type.displayTitle)
            } else if dto.success != false {
                toastMessage = String(format: NSLocalizedString("%@: changes applied.", comment: ""), type.displayTitle)
            }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    private func saveAppliedRunToApplicationIfPossible(runId: String, token: String?) async -> Bool {
        guard let appId = applicationId else { return false }
        do {
            _ = try await trackingService.saveExpertReport(applicationId: appId, runId: runId, token: token)
            savedReports = try await trackingService.fetchExpertReports(applicationId: appId, token: token)
            return true
        } catch {
            return false
        }
    }

    private func initializeSelectionIfNeeded(for type: ExpertWorkflowType, parsedOutput: ExpertOutputParsed) {
        guard type == .professionalSummaryLab || type == .coverLetterArchitect else { return }
        let count = type == .professionalSummaryLab
            ? parsedOutput.summaryOptions.count
            : parsedOutput.coverLetterVariants.count
        selectedVariantIndexByType[type] = clampedSelectionIndex(parsedOutput.recommendedIndex, count: count) ?? 0
    }

    private func clampedSelectionIndex(_ index: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let raw = index ?? 0
        return min(max(raw, 0), count - 1)
    }
}

extension ExpertWorkflowType {
    var displayTitle: String {
        switch self {
        case .fullResumeRewrite:
            return NSLocalizedString("Resume Rewrite", comment: "")
        case .achievementQuantifier:
            return NSLocalizedString("Achievement Quantifier", comment: "")
        case .atsOptimizationReport:
            return NSLocalizedString("Match Deep Report", comment: "")
        case .professionalSummaryLab:
            return NSLocalizedString("Summary Lab", comment: "")
        case .coverLetterArchitect:
            return NSLocalizedString("Cover Letter", comment: "")
        case .screeningAnswerStudio:
            return NSLocalizedString("Screening Answers", comment: "")
        }
    }

    var cardDescription: String {
        switch self {
        case .fullResumeRewrite:
            return NSLocalizedString("Role-fit rewrite with ATS-friendly structure.", comment: "")
        case .achievementQuantifier:
            return NSLocalizedString("Upgrade bullets with measurable outcomes.", comment: "")
        case .atsOptimizationReport:
            return NSLocalizedString("Keyword coverage, parse tips, formatting guidance.", comment: "")
        case .professionalSummaryLab:
            return NSLocalizedString("Five summary angles with recommendations.", comment: "")
        case .coverLetterArchitect:
            return NSLocalizedString("Tailored variants for this role.", comment: "")
        case .screeningAnswerStudio:
            return NSLocalizedString("Interview-style answers grounded in wins.", comment: "")
        }
    }

    var symbolName: String {
        switch self {
        case .fullResumeRewrite:
            return "sparkles"
        case .achievementQuantifier:
            return "chart.line.uptrend.xyaxis"
        case .atsOptimizationReport:
            return "scope"
        case .professionalSummaryLab:
            return "checkmark.seal.fill"
        case .coverLetterArchitect:
            return "doc.text.fill"
        case .screeningAnswerStudio:
            return "checkmark.square.fill"
        }
    }

    var purposeText: String {
        switch self {
        case .fullResumeRewrite:
            return NSLocalizedString("Rewrites the entire resume to match the job description with ATS-friendly structure and role-fit language.", comment: "")
        case .achievementQuantifier:
            return NSLocalizedString("Upgrades experience bullets with measurable outcomes. Add concrete metrics in Expert Input for better rewrites.", comment: "")
        case .atsOptimizationReport:
            return NSLocalizedString("Analyzes keyword coverage against the job description. Applying adds missing keywords to your Skills section.", comment: "")
        case .professionalSummaryLab:
            return NSLocalizedString("Generates five summary options in different tones. Choose one below, then apply to set it as your resume summary.", comment: "")
        case .coverLetterArchitect:
            return NSLocalizedString("Creates tailored cover letter variants. These are saved as application assets and do not change your resume.", comment: "")
        case .screeningAnswerStudio:
            return NSLocalizedString("Generates interview-style answers grounded in your resume. Saved as application assets, not resume text.", comment: "")
        }
    }

    var changesResume: Bool {
        switch self {
        case .fullResumeRewrite, .achievementQuantifier, .atsOptimizationReport, .professionalSummaryLab:
            return true
        case .coverLetterArchitect, .screeningAnswerStudio:
            return false
        }
    }

    var requiredInputHint: String? {
        switch self {
        case .achievementQuantifier:
            return NSLocalizedString("Add concrete metrics for stronger rewrites: e.g. \"grew revenue 40%, managed 12 engineers, shipped in 6 weeks\"", comment: "")
        case .coverLetterArchitect:
            return NSLocalizedString("Optional: add tone preference, specific points, or unique selling points to include", comment: "")
        default:
            return nil
        }
    }
}
