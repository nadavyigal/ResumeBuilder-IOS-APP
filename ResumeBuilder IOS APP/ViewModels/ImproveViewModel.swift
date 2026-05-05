import Foundation
import Observation

@Observable
@MainActor
final class ImproveViewModel {
    struct OptimizationResult: Sendable {
        let optimizationId: String
        let sections: [OptimizedResumeSection]
    }

    var analysis: ResumeAnalysis? = nil
    var improvements: [ResumeImprovement] = []
    var isLoading = false
    var isOptimizing = false
    var errorMessage: String? = nil
    var optimizationId: String? = nil

    private let resumeId: String?
    private let jobDescriptionId: String?
    private let jobDescription: String
    private let jobDescriptionURL: String
    private let analysisService: any ResumeAnalysisServiceProtocol
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        resumeId: String?,
        jobDescriptionId: String? = nil,
        jobDescription: String,
        jobDescriptionURL: String = "",
        initialAnalysis: ResumeAnalysis? = nil,
        initialImprovements: [ResumeImprovement] = [],
        analysisService: any ResumeAnalysisServiceProtocol = BackendConfig.useMockServices
            ? MockResumeAnalysisService() : ResumeAnalysisService(),
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService() : ResumeOptimizationService()
    ) {
        self.resumeId = resumeId
        self.jobDescriptionId = jobDescriptionId
        self.jobDescription = jobDescription
        self.jobDescriptionURL = jobDescriptionURL
        self.analysis = initialAnalysis
        self.improvements = initialImprovements
        self.analysisService = analysisService
        self.optimizationService = optimizationService
    }

    func loadAnalysis(token: String?) async {
        guard let token, let resumeId else { return }
        guard analysis == nil || improvements.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let scoreTask = analysisService.score(resumeId: resumeId, jobDescription: jobDescription, token: token)
            async let improvementsTask = analysisService.improvements(resumeId: resumeId, jobDescription: jobDescription, token: token)
            analysis = try await scoreTask
            improvements = try await improvementsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func optimize(token: String?) async -> OptimizationResult? {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return nil
        }
        guard let resumeId else {
            errorMessage = ResumeOptimizationError.missingResumeId.localizedDescription
            return nil
        }
        isOptimizing = true
        errorMessage = nil
        defer { isOptimizing = false }
        do {
            let response = try await optimizationService.optimize(resumeId: resumeId, jobDescription: jobDescription, token: token)
            guard let optimizationId = response.optimizationId else {
                throw ResumeOptimizationError.missingOptimizationId
            }
            let sections = response.sections ?? []
            self.optimizationId = optimizationId
            return OptimizationResult(optimizationId: optimizationId, sections: sections)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
