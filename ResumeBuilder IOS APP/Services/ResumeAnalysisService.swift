import Foundation

// MARK: - Wire types for POST /api/ats/score

private struct ATSScoreRequest: Encodable {
    let resume_original: String
    let resume_optimized: String
    let job_description: String
}

// MARK: - Protocol

protocol ResumeAnalysisServiceProtocol: Sendable {
    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis
    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement]
    func rescan(optimizationId: String, token: String) async throws -> ATSRescanResponse
}

// MARK: - Real service

struct ResumeAnalysisService: ResumeAnalysisServiceProtocol {
    private let apiClient = APIClient()

    // MARK: ResumeAnalysisServiceProtocol

    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        guard !resumeId.isEmpty else {
            throw APIClientError.invalidResponse
        }
        let trimmedJD = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJD.isEmpty else {
            throw APIClientError.invalidResponse
        }

        let resumeText = try await fetchResumeText(resumeId: resumeId, token: token)
        guard !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIClientError.invalidResponse
        }

        let body: [String: Any] = [
            "resume_original": resumeText,
            "resume_optimized": resumeText,
            "job_description": trimmedJD,
            "generate_quick_wins": true,
        ]
        let result: ATSAuthScoreResult = try await apiClient.postJSON(
            endpoint: .atsScore,
            body: body,
            token: token
        )

        return Self.mapATSResult(result)
    }

    func rescan(optimizationId: String, token: String) async throws -> ATSRescanResponse {
        let body: [String: Any] = [
            "optimization_id": optimizationId,
        ]
        return try await apiClient.postJSON(
            endpoint: .atsRescan,
            body: body,
            token: token
        )
    }

    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement] {
        // Improvements are surfaced through the optimization review flow rather than a
        // separate endpoint; return empty for now.
        return []
    }

    // MARK: - Private

    private func fetchResumeText(resumeId: String, token: String) async throws -> String {
        let response: ResumeTextResponse = try await apiClient.get(
            endpoint: .resumeText(id: resumeId),
            token: token
        )
        return response.rawText
    }

    private static func mapATSResult(_ result: ATSAuthScoreResult) -> ResumeAnalysis {
        let grouped = result.subscores
        let contentApprox =
            grouped.flatMap { ATSSubScores.integerAverage(of: [$0.title_alignment, $0.metrics_presence]) } ?? 0
        let designApprox =
            grouped.flatMap { ATSSubScores.integerAverage(of: [$0.format_parseability, $0.recency_fit]) } ?? 0

        return ResumeAnalysis(
            overall: result.atsScoreOptimized,
            ats: result.atsScoreOptimized,
            content: contentApprox,
            design: designApprox,
            missingKeywords: [],
            subscores: result.subscores,
            subscoresOriginal: result.subscoresOriginal,
            suggestions: result.suggestions ?? [],
            authQuickWins: result.authQuickWins ?? []
        )
    }
}
