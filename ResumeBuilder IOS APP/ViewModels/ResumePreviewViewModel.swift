import Foundation
import Observation

enum PreviewMode { case optimized, designed }

@Observable
@MainActor
final class ResumePreviewViewModel {
    var mode: PreviewMode = .optimized
    var optimizationId: String?
    var pdfData: Data? = nil
    var isExporting = false
    var isDownloading = false
    var errorMessage: String? = nil
    var exportedFileURL: URL? = nil

    private let exportService: any ResumeExportServiceProtocol

    init(
        optimizationId: String? = nil,
        exportService: any ResumeExportServiceProtocol = BackendConfig.useMockServices
            ? MockResumeExportService() : ResumeExportService()
    ) {
        self.optimizationId = optimizationId
        self.exportService = exportService
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
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("resume_export.pdf")
                try data.write(to: tempURL)
                exportedFileURL = tempURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
