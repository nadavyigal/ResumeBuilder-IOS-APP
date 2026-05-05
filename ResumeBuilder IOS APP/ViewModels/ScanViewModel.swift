import Foundation
import Observation
import UniformTypeIdentifiers

struct ResumeJobInput: Sendable {
    let resumeId: String
    let jobDescriptionId: String
    let jobDescription: String
    let jobDescriptionURL: String
    let initialScore: Int?
    let missingKeywords: [String]
    let keyImprovements: [String]
}

@Observable
@MainActor
final class ScanViewModel {
    var jobDescription: String = ""
    var jobDescriptionURL: String = ""
    var detectedFilename: String? = nil
    var selectedFileURL: URL? = nil
    var uploadedResumeId: String? = nil
    var uploadedJobDescriptionId: String? = nil
    var publicATSResult: ATSScoreResult? = nil
    var isUploading = false
    var isCheckingATS = false
    var isImporterPresented = false
    var errorMessage: String? = nil

    private let uploadService: any ResumeUploadServiceProtocol

    init(uploadService: any ResumeUploadServiceProtocol = BackendConfig.useMockServices
         ? MockResumeUploadService() : ResumeUploadService()) {
        self.uploadService = uploadService
    }

    var canAnalyze: Bool {
        selectedFileURL != nil && hasJobInput
    }

    var hasJobInput: Bool {
        !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func handlePickedFile(url: URL, token: String?) async {
        selectedFileURL = url
        detectedFilename = url.lastPathComponent
        uploadedResumeId = nil
        uploadedJobDescriptionId = nil
        publicATSResult = nil
        errorMessage = nil
    }

    func runFreeATS(appState: AppState) async {
        guard let fileURL = selectedFileURL, hasJobInput else {
            errorMessage = "Add a resume and a LinkedIn/job link or job description."
            return
        }

        isCheckingATS = true
        errorMessage = nil
        defer { isCheckingATS = false }
        do {
            let response = try await uploadService.publicATS(
                fileURL: fileURL,
                jobDescription: normalizedJobDescription,
                jobDescriptionURL: normalizedJobURL,
                sessionId: appState.anonymousATSSessionId
            )
            publicATSResult = response
            appState.storeAnonymousATSSessionId(response.sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadForOptimization(token: String?) async -> ResumeJobInput? {
        guard let token else {
            errorMessage = "Sign in to unlock full resume optimization."
            return nil
        }
        guard let fileURL = selectedFileURL, hasJobInput else {
            errorMessage = "Add a resume and a LinkedIn/job link or job description."
            return nil
        }

        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            let response = try await uploadService.upload(
                fileURL: fileURL,
                jobDescription: normalizedJobDescription,
                jobDescriptionURL: normalizedJobURL,
                token: token
            )
            guard response.success == true,
                  let resumeId = response.resumeId,
                  let jobDescriptionId = response.jobDescriptionId else {
                errorMessage = response.error ?? "Upload failed"
                return nil
            }
            uploadedResumeId = resumeId
            uploadedJobDescriptionId = jobDescriptionId
            return ResumeJobInput(
                resumeId: resumeId,
                jobDescriptionId: jobDescriptionId,
                jobDescription: normalizedJobDescription ?? "",
                jobDescriptionURL: normalizedJobURL ?? "",
                initialScore: response.matchScore,
                missingKeywords: response.missingKeywords ?? [],
                keyImprovements: response.keyImprovements ?? []
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func useSharedJobURLIfNeeded(from appState: AppState) {
        guard jobDescriptionURL.isEmpty, let url = appState.pendingSharedJobURL else { return }
        jobDescriptionURL = url.absoluteString
        appState.clearPendingSharedJobURL()
    }

    private var normalizedJobDescription: String? {
        let value = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var normalizedJobURL: String? {
        let value = jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
