import Foundation

protocol ResumeLibraryServiceProtocol: Sendable {
    func listSavedResumes(token: String) async throws -> [SavedResume]
    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume
    func deleteResume(id: String, token: String) async throws
    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume
    func downloadResumePDF(id: String, token: String) async throws -> URL
}

final class ResumeLibraryService: ResumeLibraryServiceProtocol, Sendable {
    private let apiClient = APIClient()

    func listSavedResumes(token: String) async throws -> [SavedResume] {
        let response: SavedResumesResponse = try await apiClient.get(endpoint: .savedResumes, token: token)
        return response.resumes
    }

    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        let response: SaveResumeResponse = try await apiClient.postJSON(
            endpoint: .saveResume(id: id),
            body: ["displayName": displayName],
            token: token
        )
        guard let resume = response.resume else {
            throw URLError(.badServerResponse)
        }
        return resume
    }

    func deleteResume(id: String, token: String) async throws {
        let _: APIStatusResponse = try await apiClient.postJSON(
            endpoint: .deleteResume(id: id),
            body: [:] as [String: String],
            token: token
        )
    }

    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        let response: SaveResumeResponse = try await apiClient.postJSON(
            endpoint: .renameResume(id: id),
            body: ["displayName": displayName],
            token: token
        )
        guard let resume = response.resume else {
            throw URLError(.badServerResponse)
        }
        return resume
    }

    func downloadResumePDF(id: String, token: String) async throws -> URL {
        let data = try await apiClient.getData(endpoint: .download(id: id), token: token)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).pdf")
        try data.write(to: tmp)
        return tmp
    }
}

final class MockResumeLibraryService: ResumeLibraryServiceProtocol, Sendable {
    func listSavedResumes(token: String) async throws -> [SavedResume] {
        [
            SavedResume(id: "mock-resume-1", filename: "Senior_Dev_Resume.pdf", displayName: "Senior Dev Resume", createdAt: "2026-05-10T10:00:00Z", sizeBytes: 102_400),
            SavedResume(id: "mock-resume-2", filename: "Product_Manager_Resume.pdf", displayName: nil, createdAt: "2026-05-12T14:30:00Z", sizeBytes: 87_040),
        ]
    }

    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-15T00:00:00Z", sizeBytes: nil)
    }

    func deleteResume(id: String, token: String) async throws {}

    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-15T00:00:00Z", sizeBytes: nil)
    }

    func downloadResumePDF(id: String, token: String) async throws -> URL {
        throw URLError(.unsupportedURL)
    }
}
