import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class ScanViewModel {
    var jobDescription: String = ""
    var detectedFilename: String? = nil
    var uploadedResumeId: String? = nil
    var isUploading = false
    var isImporterPresented = false
    var errorMessage: String? = nil

    private let uploadService: any ResumeUploadServiceProtocol

    init(uploadService: any ResumeUploadServiceProtocol = BackendConfig.useMockServices
         ? MockResumeUploadService() : ResumeUploadService()) {
        self.uploadService = uploadService
    }

    var canAnalyze: Bool {
        uploadedResumeId != nil && !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func handlePickedFile(url: URL, token: String?) async {
        guard let token else {
            errorMessage = "Sign in to upload your resume."
            return
        }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            let response = try await uploadService.upload(fileURL: url, token: token)
            if response.success == true {
                detectedFilename = url.lastPathComponent
                uploadedResumeId = response.resumeId
            } else {
                errorMessage = response.error ?? "Upload failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
