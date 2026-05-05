import Foundation

struct TemplateListResponse: Codable, Sendable {
    let templates: [DesignTemplate]
}

struct RenderPreviewRequest: Codable, Sendable {
    let optimizationId: String
    let templateId: String
    let customization: DesignCustomization

    private enum CodingKeys: String, CodingKey {
        case optimizationId = "optimization_id"
        case templateId     = "template_id"
        case customization
    }
}

struct RenderPreviewResponse: Codable, Sendable {
    let success: Bool?
    let previewHTML: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success
        case previewHTML = "preview_html"
        case error
    }
}

protocol ResumeDesignServiceProtocol: Sendable {
    func templates(category: String, token: String) async throws -> [DesignTemplate]
    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse
    func applyCustomization(optimizationId: String, customization: DesignCustomization, token: String) async throws -> Bool
}

struct ResumeDesignService: ResumeDesignServiceProtocol {
    private let apiClient = APIClient()

    func templates(category: String, token: String) async throws -> [DesignTemplate] {
        let response: TemplateListResponse = try await apiClient.getWithQuery(
            endpoint: .designTemplates(category: category), token: token
        )
        return response.templates
    }

    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }
        return try await apiClient.postJSON(endpoint: .designRenderPreview, body: body, token: token)
    }

    func applyCustomization(optimizationId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        let encoder = JSONEncoder()
        guard let custData = try? encoder.encode(customization),
              let body = try? JSONSerialization.jsonObject(with: custData) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }
        struct ApplyResponse: Decodable { let success: Bool? }
        let response: ApplyResponse = try await apiClient.postJSON(
            endpoint: .designCustomize(optimizationId: optimizationId), body: body, token: token
        )
        return response.success == true
    }
}
