import Foundation
import Observation

@Observable
@MainActor
final class ImproveViewModel {
    var analysis: ResumeAnalysis? = nil
    var improvements: [ResumeImprovement] = []
    var isLoading = false
    var isOptimizing = false
    var errorMessage: String? = nil
    var optimizationId: String? = nil

    private let resumeId: String?
    private let jobDescription: String
    private let analysisService: any ResumeAnalysisServiceProtocol
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        resumeId: String?,
        jobDescription: String,
        analysisService: any ResumeAnalysisServiceProtocol = BackendConfig.useMockServices
            ? MockResumeAnalysisService() : ResumeAnalysisService(),
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService() : ResumeOptimizationService()
    ) {
        self.resumeId = resumeId
        self.jobDescription = jobDescription
        self.analysisService = analysisService
        self.optimizationService = optimizationService
    }

    func loadAnalysis(token: String?) async {
        guard let token, let resumeId else { return }
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

    func optimize(token: String?) async -> String? {
        guard let token, let resumeId else { return nil }
        isOptimizing = true
        defer { isOptimizing = false }
        do {
            let response = try await optimizationService.optimize(resumeId: resumeId, jobDescription: jobDescription, token: token)
            optimizationId = response.optimizationId
            return response.optimizationId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
