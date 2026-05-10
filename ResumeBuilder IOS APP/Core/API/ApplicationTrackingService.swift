import Foundation

/// Authenticated `/api/v1/applications/*` helpers (track / compare / expert reports).
struct ApplicationTrackingService: Sendable {
    enum ServiceError: Error {
        case missingToken
    }

    var apiClient: APIClient = APIClient()

    func listApplications(token: String?) async throws -> [ApplicationItem] {
        guard let token else { throw ServiceError.missingToken }
        let envelope: ApplicationsListEnvelope = try await apiClient.get(endpoint: .applications, token: token)
        return envelope.applications
    }

    func fetchDetail(id: String, token: String?) async throws -> ApplicationDetailEnvelope {
        try await apiClient.get(endpoint: .applicationDetail(id: id), token: token)
    }

    func markApplied(id: String, token: String?) async throws {
        let _: APIStatusResponse = try await apiClient.postJSON(
            endpoint: .applicationMarkApplied(id: id),
            body: [:],
            token: token
        )
    }

    func attachOptimized(applicationId: String, optimizedResumeId: String, token: String?) async throws {
        let body: [String: Any] = ["optimized_resume_id": optimizedResumeId]
        let _: APIStatusResponse = try await apiClient.postJSON(
            endpoint: .applicationAttachOptimized(id: applicationId),
            body: body,
            token: token
        )
    }

    func fetchExpertReports(applicationId: String, token: String?) async throws -> [ApplicationExpertReportItem] {
        let env: ApplicationExpertReportsEnvelope = try await apiClient.get(
            endpoint: .applicationExpertReports(id: applicationId),
            token: token
        )
        return env.reports
    }
}
