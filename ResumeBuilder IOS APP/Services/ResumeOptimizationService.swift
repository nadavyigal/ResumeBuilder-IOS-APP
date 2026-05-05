import Foundation

struct OptimizeResponse: Codable, Sendable {
    let success: Bool?
    let sections: [OptimizedResumeSection]?
    let optimizationId: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success, sections, error
        case optimizationId = "optimization_id"
    }
}

struct RefineSectionRequest: Codable, Sendable {
    let sectionId: String
    let instruction: String
    let optimizationId: String

    private enum CodingKeys: String, CodingKey {
        case sectionId      = "section_id"
        case instruction
        case optimizationId = "optimization_id"
    }
}

struct RefineSectionResponse: Codable, Sendable {
    let success: Bool?
    let original: String?
    let suggested: String?
    let error: String?
}

struct RefineSectionApplyRequest: Codable, Sendable {
    let sectionId: String
    let optimizationId: String
    let acceptedText: String

    private enum CodingKeys: String, CodingKey {
        case sectionId      = "section_id"
        case optimizationId = "optimization_id"
        case acceptedText   = "accepted_text"
    }
}

protocol ResumeOptimizationServiceProtocol: Sendable {
    func optimize(resumeId: String, jobDescription: String, token: String) async throws -> OptimizeResponse
    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse
    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool
}

struct ResumeOptimizationService: ResumeOptimizationServiceProtocol {
    private let apiClient = APIClient()

    func optimize(resumeId: String, jobDescription: String, token: String) async throws -> OptimizeResponse {
        let body: [String: Any] = ["resume_id": resumeId, "job_description": jobDescription]
        return try await apiClient.postJSON(endpoint: .optimize, body: body, token: token)
    }

    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }
        return try await apiClient.postJSON(endpoint: .refineSection, body: body, token: token)
    }

    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }
        struct ApplyResponse: Decodable { let success: Bool? }
        let response: ApplyResponse = try await apiClient.postJSON(endpoint: .refineSectionApply, body: body, token: token)
        return response.success == true
    }
}
