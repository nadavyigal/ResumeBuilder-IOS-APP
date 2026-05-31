import Foundation

enum ResumeExportAction {
    struct Result: Sendable {
        let fileURL: URL
        let optimizationId: String
    }

    @MainActor
    static func exportPDF(
        viewModel: OptimizedResumeViewModel,
        appState: AppState,
        analytics: AnalyticsService = .shared
    ) async throws -> Result {
        guard let optimizationId = viewModel.optimizationIdentifier else {
            throw APIClientError.invalidResponse
        }
        analytics.track(.exportStarted)
        do {
            let url = try await viewModel.downloadPDF(appState: appState)
            appState.markExportComplete(for: optimizationId)
            analytics.track(.exportSuccess)
            return Result(fileURL: url, optimizationId: optimizationId)
        } catch {
            let code: String
            if let apiError = error as? APIClientError {
                switch apiError {
                case .unauthorized: code = "unauthorized"
                case .paymentRequired: code = "payment_required"
                case .invalidResponse: code = "invalid_response"
                case .invalidURL: code = "invalid_url"
                case .serverError(let status, _): code = "server_\(status)"
                }
            } else {
                code = "unknown"
            }
            analytics.track(.exportFailed(errorCode: code))
            throw error
        }
    }
}
