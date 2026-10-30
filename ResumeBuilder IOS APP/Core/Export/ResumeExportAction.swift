import Foundation

enum ResumeExportAction {
    struct Result: Sendable {
        /// The résumé PDF on its own. Kept separate from `packageFileURLs` because
        /// export completion and the review gate are about the résumé, not the extras.
        let fileURL: URL
        let optimizationId: String
        /// Everything the share sheet should carry, résumé first.
        let packageFileURLs: [URL]
        let includedCoverLetter: Bool
        let includedScreeningAnswers: Bool
        let coverLetterFailed: Bool
    }

    @MainActor
    static func exportPDF(
        viewModel: OptimizedResumeViewModel,
        appState: AppState,
        renderedHTML: String? = nil,
        /// Fetches the styled HTML when the preview hasn't produced it yet; nil means none available.
        loadStyledHTML: (@MainActor () async throws -> String?)? = nil,
        /// Whether the user had a session when they tapped export. See `authorizeExport`.
        beganSignedIn: Bool = false,
        analytics: AnalyticsService = .shared,
        unlockService: ExportUnlockService = ExportUnlockService()
    ) async throws -> Result {
        guard let optimizationId = viewModel.optimizationIdentifier else {
            throw APIClientError.invalidResponse
        }
        analytics.track(.exportStarted(optimizationId: optimizationId))
        var styledHTMLFailureCode: String?
        do {
            // The server decides first (StoreKit spec 6.4): no file is made, styled
            // or local, for an export it refused. A 402 reaches the caller as
            // ExportCreditsError.creditsRequired and opens the paywall.
            let unlock = try await appState.authorizeExport(optimizationId: optimizationId, beganSignedIn: beganSignedIn, service: unlockService)
            // The styled PDF matches the design the user picked; the server download
            // can come back as a plain layout, so it is only the last fallback.
            var styledURL: URL?
            var pdfPath = PDFPath.server
            do {
                if let html = renderedHTML {
                    pdfPath = .styledPreview
                    styledURL = try await renderStyledPDF(html: html, optimizationId: optimizationId)
                } else if let loadStyledHTML, let html = try await loadStyledHTML() {
                    pdfPath = .styledFetched
                    styledURL = try await renderStyledPDF(html: html, optimizationId: optimizationId)
                }
            } catch {
                styledHTMLFailureCode = ExportFailureCode.code(for: error)
                pdfPath = .server
            }
            let url: URL
            if let styledURL {
                url = styledURL
            } else {
                url = try await viewModel.downloadPDF(appState: appState)
                try PDFDownloadValidator.validatePDF(at: url)
            }

            // Whatever the user already generated ships with the résumé. Assembly runs
            // after validation and can only add files, so it cannot fail the export.
            let record = appState.submitPackageRecord(for: optimizationId)
            let package = await ApplicationPackageBuilder.build(
                ApplicationPackageInputs(
                    optimizationId: optimizationId,
                    resumePDFURL: url,
                    candidateName: viewModel.contact?.name,
                    jobTitle: viewModel.jobTitle?.decodingHTMLEntities(),
                    company: viewModel.company?.decodingHTMLEntities(),
                    coverLetterText: record?.coverLetterText,
                    screeningAnswers: record?.screeningAnswers ?? []
                )
            )

            // Historical export completion means validated artifact readiness, not sharing
            // or employer submission. Keep this activation/review contract compatible.
            appState.markExportComplete(for: optimizationId)
            analytics.track(.exportSuccess(
                optimizationId: optimizationId,
                hasCoverLetter: package.includedCoverLetter,
                hasScreeningAnswers: package.includedScreeningAnswers,
                pdfPath: pdfPath.rawValue
            ))
            analytics.track(.exportCompleted(optimizationId: optimizationId, source: unlock.analyticsSource))
            return Result(
                fileURL: url,
                optimizationId: optimizationId,
                packageFileURLs: package.fileURLs,
                includedCoverLetter: package.includedCoverLetter,
                includedScreeningAnswers: package.includedScreeningAnswers,
                coverLetterFailed: package.coverLetterFailed
            )
        } catch {
            let fallbackCode = ExportFailureCode.code(for: error)
            let code = styledHTMLFailureCode.map { "styled_\($0)_fallback_\(fallbackCode)" } ?? fallbackCode
            analytics.track(.exportFailed(optimizationId: optimizationId, errorCode: code))
            throw error
        }
    }

    enum PDFPath: String {
        case styledPreview = "styled_preview"
        case styledFetched = "styled_fetched"
        case server
    }

    @MainActor
    private static func renderStyledPDF(html: String, optimizationId: String) async throws -> URL {
        let url = try await HTMLPDFExporter.exportPDF(html: html, optimizationId: optimizationId)
        try PDFDownloadValidator.validatePDF(at: url)
        return url
    }
}

enum ExportFailureCode {
    static func code(for error: Error) -> String {
        if let creditsError = error as? ExportCreditsError {
            switch creditsError {
            case .creditsRequired: return "export_credits_required"
            case .accountRequired: return "account_required"
            }
        }
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

/// Coarse, groupable failure category that sits alongside `ExportFailureCode`.
///
/// `error_code` is the specific mechanical code (`server_500`, `network_1009`) and is high
/// cardinality; `reason` buckets those into a handful of values you can group a funnel by
/// without a breakdown exploding. The two are emitted together so a failure can be read at
/// either altitude (WP-52).
enum FailureReason {
    static func reason(for error: Error) -> String {
        if let creditsError = error as? ExportCreditsError {
            switch creditsError {
            case .creditsRequired: return "entitlement"
            case .accountRequired: return "auth"
            }
        }
        if let apiError = error as? APIClientError {
            switch apiError {
            case .unauthorized: return "auth"
            case .paymentRequired: return "entitlement"
            case .invalidResponse: return "malformed_response"
            case .invalidURL: return "client_config"
            case .serverError(let status, _):
                return (400...499).contains(status) ? "client_rejected" : "server_error"
            }
        }
        if error is HTMLPDFExporterError { return "timeout" }
        if error is PDFValidationError { return "validation" }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return "timeout"
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDataNotAllowed:
                return "offline"
            default:
                return "network"
            }
        }
        return "unknown"
    }
}
