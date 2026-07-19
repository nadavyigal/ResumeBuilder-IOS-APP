import Foundation
import Observation

@Observable
@MainActor
final class ResumeLibraryViewModel {
    var resumes: [SavedResume] = []
    var isLoading = false
    var errorMessage: String?
    var isUnavailable: Bool

    private let service: any ResumeLibraryServiceProtocol
    private let isEnabled: Bool

    init(
        service: any ResumeLibraryServiceProtocol = RuntimeServices.resumeLibraryService(),
        isEnabled: Bool = RuntimeFeatures.isResumeLibraryEnabled
    ) {
        self.service = service
        self.isEnabled = isEnabled
        self.isUnavailable = !isEnabled
    }

    func load(token: String) async {
        guard isEnabled else {
            resumes = []
            isUnavailable = true
            errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            resumes = try await service.listSavedResumes(token: token)
            isUnavailable = false
        } catch let apiError as APIClientError {
            if apiError.isNotFound {
                resumes = []
                isUnavailable = true
                errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            } else {
                errorMessage = apiError.userFacingMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(id: String, displayName: String, token: String) async {
        guard isEnabled else {
            isUnavailable = true
            errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            return
        }
        do {
            let saved = try await service.saveResume(id: id, displayName: displayName, token: token)
            resumes.insert(saved, at: 0)
        } catch let apiError as APIClientError {
            if apiError.isNotFound {
                isUnavailable = true
                errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            } else {
                errorMessage = apiError.userFacingMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String, token: String) async {
        guard isEnabled else {
            isUnavailable = true
            errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            return
        }
        do {
            try await service.deleteResume(id: id, token: token)
            resumes.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(id: String, displayName: String, token: String) async {
        guard isEnabled else {
            isUnavailable = true
            errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            return
        }
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
        guard isEnabled else {
            isUnavailable = true
            errorMessage = NSLocalizedString("Resume Library is not available yet.", comment: "")
            throw APIClientError.serverError(status: 404, message: NSLocalizedString("Resume Library is not available yet.", comment: ""))
        }
        // /api/download regenerates a PDF from an optimization row, not a saved_resumes
        // row - the saved-resume id and its source optimization id are different ids.
        guard let optimizationId = resume.optimizationId else {
            throw APIClientError.serverError(status: 404, message: NSLocalizedString("Download failed", comment: ""))
        }
        let remoteURL = try await service.downloadResumePDF(id: optimizationId, token: token)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("library_\(resume.id).pdf")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: remoteURL, to: dest)
        return dest
    }
}
