import Foundation

protocol ResumeUploadServiceProtocol: Sendable {
    func upload(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, token: String) async throws -> ResumeUploadResponse
    func publicATS(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, sessionId: String?) async throws -> ATSScoreResult
}

struct ResumeUploadService: ResumeUploadServiceProtocol {
    private let apiClient = APIClient()

    func upload(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, token: String) async throws -> ResumeUploadResponse {
        try await apiClient.uploadResume(
            fileURL: fileURL,
            jobDescription: jobDescription,
            jobDescriptionURL: jobDescriptionURL,
            token: token
        )
    }

    func publicATS(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, sessionId: String?) async throws -> ATSScoreResult {
        try await apiClient.runPublicATSCheck(
            resumeURL: fileURL,
            jobDescription: jobDescription,
            jobDescriptionURL: jobDescriptionURL,
            sessionId: sessionId
        )
    }
}
