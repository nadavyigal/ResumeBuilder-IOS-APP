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
    /// True when the current resume was pre-loaded from the local sandbox cache.
    var isUsingCachedResume = false

    private static let filenameKey = "savedResumeFilename"
    private static let pathKey    = "savedResumeLocalPath"

    private let uploadService: any ResumeUploadServiceProtocol

    init(uploadService: any ResumeUploadServiceProtocol = BackendConfig.useMockServices
         ? MockResumeUploadService() : ResumeUploadService()) {
        self.uploadService = uploadService
        loadCachedResume()
    }

    // MARK: - Computed

    var canAnalyze: Bool {
        selectedFileURL != nil && hasJobInput
    }

    var hasJobInput: Bool {
        !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - File handling

    func handlePickedFile(url: URL, token: String?) async {
        let fileURL = url.standardizedFileURL

        // Copy to sandbox + verify readability inside a single security-scope window.
        let (readable, localURL) = await Task.detached(priority: .userInitiated) { () -> (Bool, URL?) in
            guard fileURL.isFileURL else { return (false, nil) }
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if didAccess { fileURL.stopAccessingSecurityScopedResource() } }
            guard FileManager.default.isReadableFile(atPath: fileURL.path) else { return (false, nil) }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent("cached_resume.pdf")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: fileURL, to: dest)
            let copied = FileManager.default.fileExists(atPath: dest.path)
            return (true, copied ? dest : nil)
        }.value

        guard readable else {
            errorMessage = "Unable to read the selected file. Please choose a local PDF or DOCX file."
            selectedFileURL = nil
            detectedFilename = nil
            return
        }

        let filename = fileURL.lastPathComponent
        if let local = localURL {
            UserDefaults.standard.set(filename, forKey: Self.filenameKey)
            UserDefaults.standard.set(local.path, forKey: Self.pathKey)
            selectedFileURL = local
        } else {
            selectedFileURL = fileURL
        }
        detectedFilename = filename
        isUsingCachedResume = false
        uploadedResumeId = nil
        uploadedJobDescriptionId = nil
        publicATSResult = nil
        errorMessage = nil
    }

    /// Clears the cached resume so the user can pick a new one.
    func clearSavedResume() {
        UserDefaults.standard.removeObject(forKey: Self.filenameKey)
        UserDefaults.standard.removeObject(forKey: Self.pathKey)
        if let path = (selectedFileURL?.path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        selectedFileURL = nil
        detectedFilename = nil
        isUsingCachedResume = false
        uploadedResumeId = nil
        uploadedJobDescriptionId = nil
        publicATSResult = nil
        errorMessage = nil
    }

    // MARK: - Upload / ATS

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

    func uploadForOptimization(appState: AppState) async -> ResumeJobInput? {
        do {
            return try await appState.callWithFreshToken { token in
                try await self.uploadForOptimization(with: token)
            }
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            return nil
        }
    }

    func uploadForOptimization(token: String?) async -> ResumeJobInput? {
        guard let token else {
            errorMessage = "Sign in to unlock full resume optimization."
            return nil
        }
        do {
            return try await uploadForOptimization(with: token)
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func uploadForOptimization(with token: String) async throws -> ResumeJobInput? {
        guard let fileURL = selectedFileURL, hasJobInput else {
            errorMessage = "Add a resume and a LinkedIn/job link or job description."
            return nil
        }

        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
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
    }

    func useSharedJobURLIfNeeded(from appState: AppState) {
        guard jobDescriptionURL.isEmpty, let url = appState.pendingSharedJobURL else { return }
        jobDescriptionURL = url.absoluteString
        appState.clearPendingSharedJobURL()
    }

    // MARK: - Private

    private func loadCachedResume() {
        guard let filename = UserDefaults.standard.string(forKey: Self.filenameKey),
              let path = UserDefaults.standard.string(forKey: Self.pathKey),
              FileManager.default.fileExists(atPath: path) else {
            // Clear stale keys if file is gone.
            UserDefaults.standard.removeObject(forKey: Self.filenameKey)
            UserDefaults.standard.removeObject(forKey: Self.pathKey)
            return
        }
        selectedFileURL = URL(fileURLWithPath: path)
        detectedFilename = filename
        isUsingCachedResume = true
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
