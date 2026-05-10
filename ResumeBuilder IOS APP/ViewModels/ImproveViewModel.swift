import Foundation
import Observation

@Observable
@MainActor
final class ImproveViewModel {
    struct OptimizationResult: Sendable {
        let optimizationId: String?
        /// Set when the server uses the review-based flow; navigate to OptimizationReviewView.
        let reviewId: String?
        let sections: [OptimizedResumeSection]
    }

    var analysis: ResumeAnalysis? = nil
    var improvements: [ResumeImprovement] = []
    var isLoading = false
    var isOptimizing = false
    var errorMessage: String? = nil
    var optimizationId: String? = nil
    /// True while `/api/ats/rescan` is executing.
    var isRescanning = false

    /// Resume UUID used during optimize/upload (passed into chat screens for metadata parity).
    var sourceResumeId: String? { resumeId }

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
        optimizationId: String? = nil,
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
        self.optimizationId = optimizationId
        self.analysis = initialAnalysis
        self.improvements = initialImprovements
        self.analysisService = analysisService
        self.optimizationService = optimizationService
    }

    func loadAnalysis(token: String?, force: Bool = false) async {
        guard let token, let resumeId else { return }
        if !force, let analysis, analysis.subscores != nil {
            return
        }
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

    func rescanATS(token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optimizationId else {
            errorMessage = "Run Optimize first to create an optimization, then rescan."
            return
        }
        isRescanning = true
        errorMessage = nil
        defer { isRescanning = false }
        do {
            let response = try await analysisService.rescan(optimizationId: optimizationId, token: token)
            guard response.success ?? true else {
                throw APIClientError.invalidResponse
            }
            let updated = response.optimizedScore ?? analysis?.overall
            if let updated {
                analysis = analysis?.withUpdatedScores(overall: updated, ats: updated)
            }
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
        guard let jobDescriptionId, !jobDescriptionId.isEmpty else {
            errorMessage = "Job description is required. Please scan your resume first."
            return nil
        }
        isOptimizing = true
        errorMessage = nil
        defer { isOptimizing = false }
        do {
            let response = try await optimizationService.optimize(resumeId: resumeId, jobDescriptionId: jobDescriptionId, token: token)

            // Review-based flow: navigate to OptimizationReviewView.
            if let reviewId = response.reviewId {
                return OptimizationResult(optimizationId: nil, reviewId: reviewId, sections: [])
            }

            guard let optimizationId = response.optimizationId else {
                throw ResumeOptimizationError.missingOptimizationId
            }
            let sections = response.sections ?? []
            self.optimizationId = optimizationId
            return OptimizationResult(optimizationId: optimizationId, reviewId: nil, sections: sections)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
