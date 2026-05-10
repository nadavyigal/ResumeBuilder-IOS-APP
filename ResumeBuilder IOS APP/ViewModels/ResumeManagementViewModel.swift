import Foundation
import Observation

struct ManagedResume: Sendable {
    let id: String
    let filename: String
    let uploadedAt: String
    var previewText: String?

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: uploadedAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return uploadedAt
    }
}

@Observable
@MainActor
final class ResumeManagementViewModel {
    var currentResume: ManagedResume?
    var isLoading = false
    var isUploading = false
    var isImporterPresented = false
    var errorMessage: String?
    var uploadStatus: String?

    private let historyService: any OptimizationHistoryServiceProtocol
    private let apiClient: APIClient

    init(
        historyService: any OptimizationHistoryServiceProtocol = BackendConfig.useMockServices
        ? MockOptimizationHistoryService() : OptimizationHistoryService(),
        apiClient: APIClient = APIClient()
    ) {
        self.historyService = historyService
        self.apiClient = apiClient
    }

    func load(token: String?) async {
        guard let token else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let latest = try await historyService.list(token: token).first,
                  let resumeId = latest.resumeId else {
                currentResume = nil
                return
            }
            currentResume = ManagedResume(
                id: resumeId,
                filename: latest.filename,
                uploadedAt: latest.createdAt,
                previewText: nil
            )
            await loadPreview(resumeId: resumeId, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(fileURL: URL, token: String?) async {
        guard let token else {
            errorMessage = "Sign in to upload your resume."
            return
        }

        isUploading = true
        errorMessage = nil
        uploadStatus = nil
        defer { isUploading = false }

        do {
            let response = try await apiClient.uploadResume(fileURL: fileURL, token: token)
            guard response.success == true, let resumeId = response.resumeId else {
                errorMessage = response.error ?? "Upload failed"
                return
            }

            currentResume = ManagedResume(
                id: resumeId,
                filename: fileURL.lastPathComponent,
                uploadedAt: ISO8601DateFormatter().string(from: Date()),
                previewText: nil
            )
            uploadStatus = "Resume uploaded."
            await loadPreview(resumeId: resumeId, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPreview(resumeId: String, token: String) async {
        do {
            let response: ResumeTextResponse = try await apiClient.get(endpoint: .resumeText(id: resumeId), token: token)
            let preview = response.rawText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(220)
            currentResume?.previewText = preview.isEmpty ? nil : String(preview)
        } catch {
            // A missing preview should not hide the resume management card.
        }
    }
}
