import Foundation
import OSLog

enum ResumeOptimizationError: LocalizedError, Sendable {
    case missingToken
    case missingResumeId
    case missingOptimizationId
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Please sign in before optimizing your resume."
        case .missingResumeId:
            return "Upload a resume before running optimization."
        case .missingOptimizationId:
            return "Optimization is not ready yet. Please try again."
        case .invalidResponse(let message):
            return message
        }
    }
}

struct OptimizeResponse: Codable, Sendable {
    let success: Bool?
    let sections: [OptimizedResumeSection]?
    let optimizationId: String?
    /// Returned by the current API when the server uses the review-based flow.
    let reviewId: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success, sections, error
        case optimizationId = "optimization_id"
        case reviewId = "review_id"
    }

    private enum NestedCodingKeys: String, CodingKey {
        case data
        case optimizedResume = "optimized_resume"
    }

    init(success: Bool?, sections: [OptimizedResumeSection]?, optimizationId: String?, reviewId: String? = nil, error: String?) {
        self.success = success
        self.sections = sections
        self.optimizationId = optimizationId
        self.reviewId = reviewId
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedContainer = try? decoder.container(keyedBy: NestedCodingKeys.self)

        let nestedData = try nestedContainer?.decodeIfPresent(OptimizeResponse.self, forKey: .data)

        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? nestedData?.success
        optimizationId = try container.decodeIfPresent(String.self, forKey: .optimizationId) ?? nestedData?.optimizationId
        reviewId = try container.decodeIfPresent(String.self, forKey: .reviewId) ?? nestedData?.reviewId
        error = try container.decodeIfPresent(String.self, forKey: .error) ?? nestedData?.error

        let topSections = try container.decodeIfPresent([OptimizedResumeSection].self, forKey: .sections)
        let nestedSections = nestedData?.sections
        let optimizedResumeSections = try nestedContainer?.decodeIfPresent([OptimizedResumeSection].self, forKey: .optimizedResume)
        sections = topSections ?? nestedSections ?? optimizedResumeSections
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
    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse
    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse
    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool
}

struct ResumeOptimizationService: ResumeOptimizationServiceProtocol {
    private let apiClient = APIClient()
    private let logger = Logger(subsystem: "ResumeBuilder", category: "ResumeOptimizationService")

    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
        logger.info("Optimize start resumeId=\(resumeId, privacy: .public)")
        let body: [String: Any] = ["resumeId": resumeId, "jobDescriptionId": jobDescriptionId]
        do {
            let response: OptimizeResponse = try await apiClient.postJSON(endpoint: .optimize, body: body, token: token)
            logger.info("Optimize response success=\(response.success ?? false) sections=\(response.sections?.count ?? 0)")

            // Review-based flow: server returns reviewId instead of optimizationId+sections.
            if let reviewId = response.reviewId {
                logger.info("Optimize decode complete reviewId=\(reviewId, privacy: .public)")
                return response
            }

            if response.success == false {
                let msg = response.error ?? "Optimization did not produce results. Check that a valid job description is attached and try again."
                logger.warning("Optimize success=false message=\(msg, privacy: .public)")
                throw ResumeOptimizationError.invalidResponse(msg)
            }
            guard response.optimizationId != nil else {
                throw ResumeOptimizationError.invalidResponse("Optimization finished without an optimization identifier.")
            }
            logger.info("Optimize decode complete optimizationId=\(response.optimizationId ?? "missing", privacy: .public)")
            return response
        } catch let decodeError as DecodingError {
            logger.error("Optimize decode error: \(decodeError.localizedDescription)")
            throw ResumeOptimizationError.invalidResponse("We couldn't parse the optimization response. Please try again.")
        } catch {
            logger.error("Optimize request failed: \(error.localizedDescription)")
            throw error
        }
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
