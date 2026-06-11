import Foundation

protocol ApplicationTrackingServiceProtocol: Sendable {
    func listApplications(token: String?) async throws -> [ApplicationItem]
    func fetchDetail(id: String, token: String?) async throws -> ApplicationDetailEnvelope
    func createApplication(_ request: ApplicationCreateRequest, token: String?) async throws -> ApplicationItem
    func markApplied(id: String, token: String?) async throws
    func attachOptimized(applicationId: String, optimizedResumeId: String, token: String?) async throws
    func fetchExpertReports(applicationId: String, token: String?) async throws -> [ApplicationExpertReportItem]
    func saveExpertReport(applicationId: String, runId: String, token: String?) async throws -> ApplicationExpertReportItem
}

/// Authenticated `/api/v1/applications/*` helpers (track / compare / expert reports).
struct ApplicationTrackingService: ApplicationTrackingServiceProtocol, Sendable {
    enum ServiceError: Error {
        case missingToken
    }

    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    func listApplications(token: String?) async throws -> [ApplicationItem] {
        guard let token else { throw ServiceError.missingToken }
        let envelope: ApplicationsListEnvelope = try await apiClient.get(endpoint: .applications, token: token)
        return envelope.applications
    }

    func fetchDetail(id: String, token: String?) async throws -> ApplicationDetailEnvelope {
        try await apiClient.get(endpoint: .applicationDetail(id: id), token: token)
    }

    func createApplication(_ request: ApplicationCreateRequest, token: String?) async throws -> ApplicationItem {
        guard let token else { throw ServiceError.missingToken }
        let envelope: ApplicationCreateEnvelope = try await apiClient.postJSONObject(
            endpoint: .applications,
            bodyObject: ApplicationCreateRequestBody.build(request),
            token: token
        )
        return envelope.application
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

    func saveExpertReport(applicationId: String, runId: String, token: String?) async throws -> ApplicationExpertReportItem {
        guard !runId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIClientError.invalidResponse
        }
        let envelope: ApplicationExpertReportSaveEnvelope = try await apiClient.postJSON(
            endpoint: .applicationExpertReports(id: applicationId),
            body: ["run_id": runId],
            token: token
        )
        return envelope.report
    }
}
