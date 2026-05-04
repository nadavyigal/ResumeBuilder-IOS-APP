import Foundation

protocol ResumeUploadServiceProtocol: Sendable {
    func upload(fileURL: URL, token: String) async throws -> ResumeUploadResponse
}

struct ResumeUploadService: ResumeUploadServiceProtocol {
    private let apiClient = APIClient()

    func upload(fileURL: URL, token: String) async throws -> ResumeUploadResponse {
        try await apiClient.uploadResume(fileURL: fileURL, token: token)
    }
}
