import Foundation
import Observation

@Observable
@MainActor
final class ApplicationsViewModel {
    var applications: [ApplicationItem] = []
    var optimizations: [OptimizationItem] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient = APIClient()

    func load(token: String?) async {
        guard let token else {
            errorMessage = "Please sign in first."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let applicationsResponse: ApplicationsResponse = try await apiClient.get(endpoint: .applications, token: token)
            applications = applicationsResponse.applications
            let optimizationsResponse: OptimizationHistoryResponse = try await apiClient.get(endpoint: .optimizations, token: token)
            optimizations = optimizationsResponse.resolvedOptimizations
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
