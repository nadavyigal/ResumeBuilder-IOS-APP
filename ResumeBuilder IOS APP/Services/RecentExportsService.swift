import Foundation

protocol RecentExportsServiceProtocol: Sendable {
    func list(token: String) async throws -> [ResumeExport]
}

struct RecentExportsService: RecentExportsServiceProtocol {
    private let apiClient = APIClient()

    func list(token: String) async throws -> [ResumeExport] {
        struct Response: Decodable {
            let optimizations: [ResumeExport]?
            let data: [ResumeExport]?
            let items: [ResumeExport]?
        }
        let response: Response = try await apiClient.get(endpoint: .optimizations, token: token)
        return response.optimizations ?? response.data ?? response.items ?? []
    }
}
