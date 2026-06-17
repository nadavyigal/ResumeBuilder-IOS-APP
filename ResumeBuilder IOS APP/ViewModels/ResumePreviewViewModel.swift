import Foundation
import Observation

enum PreviewMode { case optimized, designed }

@Observable
@MainActor
final class ResumePreviewViewModel {
    var mode: PreviewMode = .optimized
    var optimizationId: String?
    /// ATS headline percent for social copy (optional).
    var atsScorePercent: Int?
    var pdfData: Data? = nil
    var isExporting = false
    var isDownloading = false
    var errorMessage: String? = nil
    var exportedFileURL: URL? = nil

    private let exportService: any ResumeExportServiceProtocol

    static let shareAppURL = "https://new-resume-builder-ai.vercel.app"

    init(
        optimizationId: String? = nil,
        atsScorePercent: Int? = nil,
        exportService: any ResumeExportServiceProtocol = RuntimeServices.resumeExportService()
    ) {
        self.optimizationId = optimizationId
        self.atsScorePercent = atsScorePercent
        self.exportService = exportService
    }

    /// Plain-text blurb for `ShareLink` message and copy button.
    var shareScoreLine: String? {
        guard let s = atsScorePercent else { return nil }
        return String(format: NSLocalizedString("My resume scored %lld%% on ATS — try ResumeBuilder AI: %@", comment: ""), s, Self.shareAppURL)
    }

    var shareScoreMessage: String {
        shareScoreLine ?? String(format: NSLocalizedString("Resume export — try ResumeBuilder AI: %@", comment: ""), Self.shareAppURL)
    }

    func downloadPDF(token: String?) async {
        guard let token, let optId = optimizationId else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let exportResponse = try await exportService.exportPDF(optimizationId: optId, token: token)
            if let exportId = exportResponse.exportId {
                let data = try await exportService.downloadPDF(id: exportId, token: token)
                pdfData = data
                let tempURL = try await Task.detached(priority: .utility) {
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("resume_export.pdf")
                    try data.write(to: destination)
                    return destination
                }.value
                exportedFileURL = tempURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
