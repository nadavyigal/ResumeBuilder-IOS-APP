import Foundation

protocol OptimizationHistoryServiceProtocol: Sendable {
    func list(token: String) async throws -> [OptimizationHistoryItem]
    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse
}

struct OptimizationHistoryService: OptimizationHistoryServiceProtocol {
    private let apiClient = APIClient()

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

struct MockOptimizationHistoryService: OptimizationHistoryServiceProtocol {
    func list(token: String) async throws -> [OptimizationHistoryItem] {
        try await Task.sleep(for: .milliseconds(300))
        return [
            OptimizationHistoryItem(
                id: "mock-1",
                createdAt: "2026-05-01T12:00:00Z",
                jobTitle: "Senior iOS Engineer",
                company: "Apple",
                matchScorePercent: 88,
                contentScorePercent: 82,
                designScorePercent: 91,
                keywordScorePercent: 76,
                status: "completed",
                resumeId: "resume-1",
                reviewId: "mock-review-1"
            ),
            OptimizationHistoryItem(
                id: "mock-2",
                createdAt: "2026-04-28T09:30:00Z",
                jobTitle: "Product Engineer",
                company: "Stripe",
                matchScorePercent: 74,
                contentScorePercent: 78,
                designScorePercent: 80,
                keywordScorePercent: 69,
                status: "completed",
                resumeId: "resume-2",
                reviewId: nil
            ),
        ]
    }

    func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
        BulkDeleteResponse(success: true, deleted: ids.count, errors: nil)
    }
}
