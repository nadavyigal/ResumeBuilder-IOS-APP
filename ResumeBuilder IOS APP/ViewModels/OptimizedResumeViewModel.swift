import Foundation
import Observation

@Observable
@MainActor
final class OptimizedResumeViewModel {
    var sections: [OptimizedResumeSection]
    var isRefining = false
    var isSaving = false
    var errorMessage: String? = nil
    var pendingRefine: (original: String, suggested: String)? = nil
    var activeSectionId: String? = nil

    private let optimizationId: String?
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        optimizationId: String?,
        sections: [OptimizedResumeSection] = [],
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService() : ResumeOptimizationService()
    ) {
        self.optimizationId = optimizationId
        self.sections = sections
        self.optimizationService = optimizationService
    }

    func refineSection(sectionId: String, instruction: String, token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }
        isRefining = true
        activeSectionId = sectionId
        errorMessage = nil
        defer { isRefining = false }
        do {
            let request = RefineSectionRequest(sectionId: sectionId, instruction: instruction, optimizationId: optId)
            let response = try await optimizationService.refineSection(request, token: token)
            if response.success == true {
                pendingRefine = (original: response.original ?? "", suggested: response.suggested ?? "")
            } else {
                errorMessage = response.error ?? "Refine failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRefine(sectionId: String, acceptedText: String, token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let request = RefineSectionApplyRequest(sectionId: sectionId, optimizationId: optId, acceptedText: acceptedText)
            let success = try await optimizationService.applySectionRefine(request, token: token)
            if success, let idx = sections.firstIndex(where: { $0.id == sectionId }) {
                sections[idx].body = acceptedText
                sections[idx].status = "improved"
            }
            pendingRefine = nil
            activeSectionId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRefine() {
        pendingRefine = nil
        activeSectionId = nil
    }
}
