import Foundation
import Observation

@Observable
@MainActor
final class ResumeLibraryViewModel {
    var resumes: [SavedResume] = []
    var isLoading = false
    var errorMessage: String?

    private let service: any ResumeLibraryServiceProtocol

    init(service: any ResumeLibraryServiceProtocol = BackendConfig.useMockLibraryService
        ? MockResumeLibraryService()
        : ResumeLibraryService()
    ) {
        self.service = service
    }

    func load(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            resumes = try await service.listSavedResumes(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(id: String, displayName: String, token: String) async {
        do {
            let saved = try await service.saveResume(id: id, displayName: displayName, token: token)
            resumes.insert(saved, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String, token: String) async {
        do {
            try await service.deleteResume(id: id, token: token)
            resumes.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(id: String, displayName: String, token: String) async {
        do {
            let updated = try await service.renameResume(id: id, displayName: displayName, token: token)
            if let idx = resumes.firstIndex(where: { $0.id == id }) {
                resumes[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Downloads the PDF for a saved resume into the sandbox cache.
    /// Returns the local file URL on success.
    func downloadToCache(resume: SavedResume, token: String) async throws -> URL {
        let remoteURL = try await service.downloadResumePDF(id: resume.id, token: token)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("library_\(resume.id).pdf")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: remoteURL, to: dest)
        return dest
    }
}
