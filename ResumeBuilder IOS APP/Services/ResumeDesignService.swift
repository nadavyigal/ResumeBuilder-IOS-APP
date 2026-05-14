import Foundation

struct TemplateListResponse: Codable, Sendable {
    let templates: [DesignTemplate]
}

struct RenderPreviewRequest: Codable, Sendable {
    let optimizationId: String
    let templateId: String
    let customization: DesignCustomization
    let resumeData: [String: JSONValue]?

    private enum CodingKeys: String, CodingKey {
        case optimizationId = "optimization_id"
        case templateId     = "template_id"
        case customization
        case resumeData
    }
}

struct RenderPreviewResponse: Codable, Sendable {
    let success: Bool?
    let previewHTML: String?
    let error: String?

    init(success: Bool?, previewHTML: String?, error: String?) {
        self.success = success
        self.previewHTML = previewHTML
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case previewHTML = "preview_html"
        case error
    }
}

protocol ResumeDesignServiceProtocol: Sendable {
    func templates(category: String, token: String) async throws -> [DesignTemplate]
    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse
    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool
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
        // The backend returns raw HTML (Content-Type: text/html), not a JSON envelope.
        // Build the request manually so we can read the raw string response.
        var components = URLComponents(url: BackendConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
        components.path = Endpoint.designRenderPreview.path
        guard let url = components.url else { throw APIClientError.invalidResponse }
        var urlRequest = URLRequest(url: url, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIClientError.invalidResponse
        }
        let html = String(data: responseData, encoding: .utf8) ?? ""
        return RenderPreviewResponse(success: true, previewHTML: html, error: nil)
    }

    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        struct AssignmentResponse: Decodable { let assignment: JSONValue? }
        let _: AssignmentResponse = try await apiClient.postJSON(
            endpoint: .designAssignment(optimizationId: optimizationId),
            body: ["templateId": templateId],
            token: token
        )

        let encoder = JSONEncoder()
        guard let custData = try? encoder.encode(customization),
              let body = try? JSONSerialization.jsonObject(with: custData) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }
        struct ApplyResponse: Decodable {
            let success: Bool?
            let customization: JSONValue?
        }
        let response: ApplyResponse = try await apiClient.postJSON(
            endpoint: .designCustomize(optimizationId: optimizationId), body: body, token: token
        )
        return response.success == true || response.customization != nil
    }
}
