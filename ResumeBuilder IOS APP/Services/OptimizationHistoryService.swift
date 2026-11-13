import Foundation

protocol OptimizationHistoryServiceProtocol: Sendable {
    func list(token: String) async throws -> [OptimizationHistoryItem]
    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse
}

struct OptimizationHistoryService: OptimizationHistoryServiceProtocol {
    private let apiClient = RuntimeServices.sharedAPIClient

    func list(token: String) async throws -> [OptimizationHistoryItem] {
        let response: OptimizationHistoryResponse = try await apiClient.get(endpoint: .optimizations, token: token)
        return response.allItems
    }

    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
        try await apiClient.deleteJSON(
            endpoint: .optimizationsBulk,
            body: ["ids": ids],
            token: token
        )
    }
}
