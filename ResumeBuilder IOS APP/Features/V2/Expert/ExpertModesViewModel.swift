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

    private let optimizationId: String
    /// When `nil` (e.g. opened from **Track**), apply still runs on the server but local resume sections are not merged.
    private let resumeViewModel: OptimizedResumeViewModel?
    private let service: ExpertWorkflowService

    init(
        optimizationId: String,
        resumeViewModel: OptimizedResumeViewModel?,
        service: ExpertWorkflowService = ExpertWorkflowService()
    ) {
        self.optimizationId = optimizationId
        self.resumeViewModel = resumeViewModel
        self.service = service
        for t in ExpertWorkflowType.allCases {
            phaseByType[t] = .idle
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    func phase(for type: ExpertWorkflowType) -> ExpertCardPhase {
        phaseByType[type] ?? .idle
    }

    func run(_ type: ExpertWorkflowType, token: String?) async {
        phaseByType[type] = .running
        do {
            let dto = try await service.run(type: type, optimizationId: optimizationId, token: token)
            phaseByType[type] = .ready(
                ExpertRunUIState(
                    workflowType: type,
                    runId: dto.runId,
                    status: dto.status,
                    output: dto.output,
                    missingEvidence: dto.missingEvidence ?? [],
                    needsUserInput: dto.needsUserInput ?? (dto.status == "needs_user_input")
                )
            )
        } catch ExpertWorkflowServiceError.premiumRequired(let message) {
            phaseByType[type] = .failed(message)
        } catch {
            phaseByType[type] = .failed(error.localizedDescription)
        }
    }

    func apply(_ type: ExpertWorkflowType, token: String?, appState: AppState) async {
        guard case .ready(let state) = phaseByType[type] else { return }
        applyingWorkflow = type
        defer { applyingWorkflow = nil }
        do {
            let dto = try await service.apply(
                runId: state.runId,
                workflowType: type,
                token: token,
                selectionIndex: (type == .professionalSummaryLab || type == .coverLetterArchitect) ? 0 : nil,
                screeningSelectedIndices: (type == .screeningAnswerStudio) ? [0] : nil
            )
            if let resumeViewModel {
                await resumeViewModel.forceReloadSections(appState: appState)
                resumeViewModel.mergeExpertApply(workflowType: type, output: state.output, applyResult: dto)
            }

            let touchedResume = dto.updatedFields.contains(where: {
                $0.contains("summary")
                    || $0.contains("skills")
                    || $0.contains("experience")
                    || $0.contains("entire_resume")
            })
            if resumeViewModel == nil, dto.success != false {
                toastMessage = "\(type.displayTitle): applied on server. Open Optimize to refresh resume text."
            } else if !touchedResume, dto.success != false {
                toastMessage =
                    "\(type.displayTitle): applied — ancillary assets saved (no resume text changes)."
            } else if dto.success != false {
                toastMessage = "\(type.displayTitle): changes applied."
            }
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}

extension ExpertWorkflowType {
    var displayTitle: String {
        switch self {
        case .fullResumeRewrite:
            return "Resume Rewrite"
        case .achievementQuantifier:
            return "Achievement Quantifier"
        case .atsOptimizationReport:
            return "ATS Deep Report"
        case .professionalSummaryLab:
            return "Summary Lab"
        case .coverLetterArchitect:
            return "Cover Letter"
        case .screeningAnswerStudio:
            return "Screening Answers"
        }
    }

    var cardDescription: String {
        switch self {
        case .fullResumeRewrite:
            return "Role-fit rewrite with ATS-safe structure."
        case .achievementQuantifier:
            return "Upgrade bullets with measurable outcomes."
        case .atsOptimizationReport:
            return "Keyword coverage, compliance, formatting tips."
        case .professionalSummaryLab:
            return "Five summary angles with recommendations."
        case .coverLetterArchitect:
            return "Tailored variants for this role."
        case .screeningAnswerStudio:
            return "Interview-style answers grounded in wins."
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
}
