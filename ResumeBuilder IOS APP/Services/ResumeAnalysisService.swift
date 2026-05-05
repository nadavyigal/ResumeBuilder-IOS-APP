import Foundation

struct ATSScoreRequest: Codable, Sendable {
    let resumeOriginal: String
    let resumeOptimized: String
    let jobDescription: String

    private enum CodingKeys: String, CodingKey {
        case resumeOriginal  = "resume_original"
        case resumeOptimized = "resume_optimized"
        case jobDescription  = "job_description"
    }
}

struct FullAnalysisResponse: Codable, Sendable {
    let success: Bool?
    let score: ResumeAnalysis?
    let improvements: [ResumeImprovement]?
    let error: String?
}

protocol ResumeAnalysisServiceProtocol: Sendable {
    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis
    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement]
}

struct ResumeAnalysisService: ResumeAnalysisServiceProtocol {
    private let apiClient = APIClient()

    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        let body: [String: Any] = [
            "resume_id": resumeId,
            "job_description": jobDescription
        ]
        let result: ATSScoreResult = try await apiClient.postJSON(endpoint: .atsScore, body: body, token: token)
        guard let payload = result.score else {
            throw APIClientError.invalidResponse
        }
        return ResumeAnalysis(
            overall: payload.overall ?? 0,
            ats: payload.overall ?? 0,
            content: 0,
            design: 0,
            missingKeywords: []
        )
    }

    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement] {
        []
    }
}
