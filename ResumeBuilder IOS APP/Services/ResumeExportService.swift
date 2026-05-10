import Foundation

protocol ResumeExportServiceProtocol: Sendable {
    func exportPDF(optimizationId: String, token: String) async throws -> ExportResponse
    func downloadPDF(id: String, token: String) async throws -> Data
}

struct ResumeExportService: ResumeExportServiceProtocol {
    private let apiClient = APIClient()

    func exportPDF(optimizationId: String, token: String) async throws -> ExportResponse {
        let body: [String: Any] = ["optimization_id": optimizationId]
        return try await apiClient.postJSON(endpoint: .optimizationsExport, body: body, token: token)
    }

    func downloadPDF(id: String, token: String) async throws -> Data {
        try await apiClient.getData(endpoint: .download(id: id), token: token)
    }
}
