import Foundation

enum ResumeExportAction {
    struct Result: Sendable {
        let fileURL: URL
        let optimizationId: String
    }

    @MainActor
    static func exportPDF(
        viewModel: OptimizedResumeViewModel,
        appState: AppState,
        renderedHTML: String? = nil,
        analytics: AnalyticsService = .shared
    ) async throws -> Result {
        guard let optimizationId = viewModel.optimizationIdentifier else {
            throw APIClientError.invalidResponse
        }
        analytics.track(.exportStarted(optimizationId: optimizationId))
        var styledHTMLFailureCode: String?
        do {
            let url: URL
            if let html = renderedHTML {
                // Generate PDF from the already-rendered styled HTML so the exported
                // PDF matches the design template the user applied in the Design tab.
                do {
                    let styledURL = try await HTMLPDFExporter.exportPDF(html: html, optimizationId: optimizationId)
                    try PDFDownloadValidator.validatePDF(at: styledURL)
                    url = styledURL
                } catch {
                    styledHTMLFailureCode = ExportFailureCode.code(for: error)
                    url = try await viewModel.downloadPDF(appState: appState)
                }
            } else {
                url = try await viewModel.downloadPDF(appState: appState)
            }
            try PDFDownloadValidator.validatePDF(at: url)
            appState.markExportComplete(for: optimizationId)
            analytics.track(.exportSuccess(optimizationId: optimizationId))
            return Result(fileURL: url, optimizationId: optimizationId)
        } catch {
            let fallbackCode = ExportFailureCode.code(for: error)
            let code = styledHTMLFailureCode.map { "styled_\($0)_fallback_\(fallbackCode)" } ?? fallbackCode
            analytics.track(.exportFailed(optimizationId: optimizationId, errorCode: code))
            throw error
        }
    }
}

enum ExportFailureCode {
    static func code(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .unauthorized: return "unauthorized"
            case .paymentRequired: return "payment_required"
            case .invalidResponse: return "invalid_response"
            case .invalidURL: return "invalid_url"
            case .serverError(let status, _): return "server_\(status)"
            }
        }
        if let htmlError = error as? HTMLPDFExporterError {
            switch htmlError {
            case .timedOut: return "html_pdf_timed_out"
            }
        }
        if error is PDFValidationError { return "missing_text_layer" }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "network_\(abs(nsError.code))"
        }
        return "unknown"
    }
}
