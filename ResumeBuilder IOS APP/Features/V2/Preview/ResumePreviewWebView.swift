import SwiftUI
import WebKit
import OSLog

private let previewLogger = Logger(subsystem: "ResumeBuilder", category: "ResumePreview")

struct ResumePreviewWebView: View {
    @Environment(AppState.self) private var appState
    let optimizationId: String
    let sections: [OptimizedResumeSection]
    var contact: ResumeContact? = nil
    var templateId: String? = nil
    var customization: DesignCustomization? = nil
    var isActive = true
    var renderDebounce: Duration = .zero
    /// Optional binding — when provided, updated each time the rendered HTML changes.
    /// The parent can read this to generate a PDF that matches the displayed design.
    var renderedHTML: Binding<String?> = .constant(nil)

    @State private var html: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pdfURL: URL?
    @State private var showSharePDF = false
    @State private var isDownloadingPDF = false
    @State private var previewPolicy = PreviewRequestPolicy()

    private let designService: any ResumeDesignServiceProtocol = RuntimeServices.resumeDesignService()
    private var previewRequestKey: String {
        let localeKey = LocalizationManager.shared.language.rawValue
        let sectionKey = sections
            .map { "\($0.id):\($0.type.rawValue):\($0.status):\($0.body)" }
            .joined(separator: "|")
        let customizationKey = customization.map { "\($0.spacing):\($0.accentColor):\($0.fontStyle)" } ?? "default"
        let contactKey = contact.map { "\($0.name ?? ""):\($0.email ?? ""):\($0.phone ?? ""):\($0.location ?? ""):\($0.linkedin ?? "")" } ?? "no-contact"
        return "\(optimizationId)|\(templateId ?? "ats-clean")|\(customizationKey)|\(contactKey)|\(sectionKey.hashValue)|\(localeKey)"
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .tint(AppColors.accentViolet)
                    Text("Rendering preview…")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let html {
                WebKitHTMLView(html: html, baseURL: BackendConfig.apiBaseURL) { message in
                    previewLogger.error("Preview WebKit load failed for optimization \(optimizationId, privacy: .public): \(message, privacy: .public)")
                    errorMessage = NSLocalizedString("Preview unavailable. Try downloading the PDF instead.", comment: "")
                    self.html = nil
                }
                    .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(errorMessage ?? NSLocalizedString("Preview unavailable", comment: ""))
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                    Button("Try Again") {
                        previewPolicy.reset()
                        Task { await renderPreview(key: previewRequestKey) }
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.accentTeal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await downloadAndShare() }
                } label: {
                    if isDownloadingPDF {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isLoading || isDownloadingPDF)
            }
        }
        .task(id: previewRequestKey) {
            guard isActive else { return }
            if renderDebounce > .zero {
                do {
                    try await Task.sleep(for: renderDebounce)
                } catch {
                    return
                }
            }
            await renderPreview(key: previewRequestKey)
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            Task { await renderPreview(key: previewRequestKey) }
        }
        .sheet(isPresented: $showSharePDF, onDismiss: { pdfURL = nil }) {
            if let url = pdfURL {
                ShareSheet(items: [url]).ignoresSafeArea()
            }
        }
    }

    // MARK: - Private

    private func renderPreview(key: String) async {
        guard isActive else { return }
        guard previewPolicy.shouldRender(key: key) else { return }
        previewPolicy.markStarted(key: key)
        var didRender = false
        defer { previewPolicy.markFinished(key: key, didRender: didRender) }

        #if DEBUG
        print("🎨 [PREVIEW] renderPreview start: optId=\(optimizationId) sections=\(sections.count)")
        #endif
        if let cachedHTML = PreviewHTMLCache.html(for: key) {
            html = cachedHTML
            isLoading = false
            errorMessage = nil
            didRender = true
            #if DEBUG
            print("✅ [PREVIEW] using cached rendered HTML")
            #endif
            return
        }

        if !sections.isEmpty {
            html = ResumeHTMLBuilder.build(sections: sections, contact: contact, customization: customization)
            isLoading = false
            errorMessage = nil
            #if DEBUG
            print("✅ [PREVIEW] showing local HTML while backend render finishes")
            #endif
        }

        guard let token = appState.session?.accessToken else {
            if !sections.isEmpty {
                #if DEBUG
                print("✅ [PREVIEW] no token — using local fallback")
                #endif
                didRender = true
            } else {
                #if DEBUG
                print("❌ [PREVIEW] no token — cannot render")
                #endif
                errorMessage = NSLocalizedString("Sign in to preview your resume.", comment: "")
            }
            isLoading = false
            return
        }
        isLoading = sections.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let request = RenderPreviewRequest(
                optimizationId: optimizationId,
                templateId: templateId ?? "ats-clean",
                customization: customization ?? .default,
                resumeData: nil,
                locale: LocalizationManager.shared.language.rawValue
            )
            let response = try await designService.renderPreview(request, token: token)
            #if DEBUG
            print("🎨 [PREVIEW] renderPreview response: html=\(response.previewHTML?.count ?? 0) chars error=\(response.error ?? "none")")
            #endif
            if let previewHTML = response.previewHTML, !previewHTML.isEmpty {
                #if DEBUG
                print("✅ [PREVIEW] using rendered HTML")
                #endif
                // Ensure RTL output for Hebrew résumés even if the backend ignored
                // the locale hint. Direction is decided from the résumé content so
                // an English résumé is never forced RTL.
                // When sections are empty, detect direction from the rendered text
                // only — strip tags first so Latin tag/attribute names don't skew it.
                let plainPreviewText = previewHTML.replacingOccurrences(
                    of: "<[^>]+>", with: " ", options: .regularExpression
                )
                let rtl = ResumeTextDirection.isRTL(sections: sections, contact: contact)
                    || (sections.isEmpty && ResumeTextDirection.isRTLText(plainPreviewText))
                let finalHTML = ResumeHTMLDirection.applyRTLIfNeeded(to: previewHTML, isRTL: rtl)
                html = finalHTML
                renderedHTML.wrappedValue = finalHTML
                PreviewHTMLCache.store(finalHTML, for: key)
                didRender = true
            } else if !sections.isEmpty {
                #if DEBUG
                print("⚠️ [PREVIEW] backend returned no HTML — using local fallback")
                #endif
                didRender = true
            } else {
                #if DEBUG
                print("❌ [PREVIEW] no html and no sections available")
                #endif
                errorMessage = response.error ?? NSLocalizedString("Preview unavailable. Try downloading the PDF instead.", comment: "")
            }
        } catch where PreviewRenderErrorPolicy.isBenignCancellation(error) {
            // SwiftUI cancels preview tasks during view refreshes; that is not a render failure.
        } catch {
            #if DEBUG
            print("❌ [PREVIEW] renderPreview error: \(error)")
            #endif
            if !sections.isEmpty {
                didRender = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func downloadAndShare() async {
        guard let token = appState.session?.accessToken else { return }
        isDownloadingPDF = true
        AnalyticsService.shared.track(.exportPdfTapped)
        AnalyticsService.shared.track(.exportStarted)
        defer { isDownloadingPDF = false }
        // Use the already-rendered styled HTML when available so the exported PDF
        // includes the design template the user selected.
        var styledHTMLFailureCode: String?
        if let styledHTML = html {
            do {
                let dest = try await HTMLPDFExporter.exportPDF(html: styledHTML, optimizationId: optimizationId)
                pdfURL = dest
                showSharePDF = true
                AnalyticsService.shared.track(.exportSuccess)
                return
            } catch {
                styledHTMLFailureCode = ExportFailureCode.code(for: error)
                previewLogger.error("Preview styled PDF export failed for optimization \(optimizationId, privacy: .public): \(styledHTMLFailureCode ?? "unknown", privacy: .public)")
                // Fall through to backend download on failure.
            }
        }
        do {
            let data = try await PDFExporter.downloadPDFData(optimizationId: optimizationId, token: token)
            let dest = try ExportFileStore.writePDFData(data, optimizationId: optimizationId)
            pdfURL = dest
            showSharePDF = true
            AnalyticsService.shared.track(.exportSuccess)
        } catch {
            let fallbackCode = ExportFailureCode.code(for: error)
            let code = styledHTMLFailureCode.map { "styled_\($0)_fallback_\(fallbackCode)" } ?? fallbackCode
            AnalyticsService.shared.track(.exportFailed(errorCode: code))
            previewLogger.error("Preview backend PDF export failed for optimization \(optimizationId, privacy: .public): \(code, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

}

@MainActor
private enum PreviewHTMLCache {
    private static var storage: [String: String] = [:]
    private static var order: [String] = []
    private static let limit = 12

    static func html(for key: String) -> String? {
        storage[key]
    }

    static func store(_ html: String, for key: String) {
        storage[key] = html
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}

enum PreviewRenderErrorPolicy {
    static func isBenignCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

struct PreviewRequestPolicy {
    private var lastRenderedKey: String?
    private var inFlightKey: String?

    mutating func shouldRender(key: String) -> Bool {
        lastRenderedKey != key && inFlightKey != key
    }

    mutating func markStarted(key: String) {
        inFlightKey = key
    }

    mutating func markFinished(key: String, didRender: Bool) {
        if inFlightKey == key {
            inFlightKey = nil
        }
        if didRender {
            lastRenderedKey = key
        }
    }

    mutating func reset() {
        lastRenderedKey = nil
        inFlightKey = nil
    }
}

// MARK: - WKWebView wrapper

private struct WebKitHTMLView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let onLoadFailure: @MainActor (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFailure: onLoadFailure)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLoadFailure = onLoadFailure
        guard context.coordinator.lastLoadedHTML != html else { return }
        context.coordinator.lastLoadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
        var onLoadFailure: @MainActor (String) -> Void

        init(onLoadFailure: @escaping @MainActor (String) -> Void) {
            self.onLoadFailure = onLoadFailure
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleFailure(error)
        }

        private func handleFailure(_ error: Error) {
            let nsError = error as NSError
            guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
            lastLoadedHTML = nil
            onLoadFailure(error.localizedDescription)
        }
    }
}

// MARK: - Client-side HTML builder

enum ResumeHTMLBuilder {
    /// Builds a printable resume HTML page from locally loaded sections.
    /// Used as fallback when the backend render-preview endpoint is unavailable.
    static func build(sections: [OptimizedResumeSection], contact: ResumeContact?, customization: DesignCustomization?) -> String {
        let accent = customization?.accentColor ?? "6366F1"
        let displayName = contact?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = contact?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contactLine = contact?.contactLine ?? ""
        let headerHTML: String
        if displayName.isEmpty && title.isEmpty && contactLine.isEmpty {
            headerHTML = ""
        } else {
            headerHTML = """
            <div class="resume-header">
              \(displayName.isEmpty ? "" : "<div class=\"resume-name\">\(displayName)</div>")
              \(title.isEmpty ? "" : "<div class=\"resume-title\">\(title)</div>")
              \(contactLine.isEmpty ? "" : "<div class=\"resume-contact\">\(contactLine)</div>")
            </div>
            <hr class="divider">
            """
        }
        var body = ""
        for section in sections {
            let title = section.type.displayName.uppercased()
            let content = section.body
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    let l = String(line)
                    if l.hasPrefix("•") || l.hasPrefix("-") {
                        return "<li>\(l.dropFirst().trimmingCharacters(in: .whitespaces))</li>"
                    }
                    return l.isEmpty ? "<br>" : "<p>\(l)</p>"
                }
                .joined()
            let wrapped = content.contains("<li>")
                ? "<ul>\(content)</ul>"
                : content
            body += """
            <h2>\(title)</h2>
            <div class="section">\(wrapped)</div>
            <hr class="divider">
            """
        }

        // RTL résumés (Hebrew content) need a flipped document direction, a
        // Hebrew-capable font, and logical list indentation on the right.
        let isRTL = ResumeTextDirection.isRTL(sections: sections, contact: contact)
        let dirAttr = isRTL ? " dir=\"rtl\"" : ""
        let bodyDirection = isRTL ? "direction: rtl; text-align: right; " : ""
        let fontFamily = isRTL ? ResumeHTMLDirection.hebrewFontStack : "Georgia, serif"
        let listIndent = isRTL ? "margin-right: 16px;" : "margin-left: 16px;"

        return """
        <!DOCTYPE html>
        <html\(dirAttr)>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { \(bodyDirection)font-family: \(fontFamily); font-size: 10pt; color: #1a1a1a; background: #fff; padding: 36px 44px; line-height: 1.5; }
          .resume-header { text-align: center; padding-bottom: 10px; }
          .resume-name { font-size: 18pt; font-weight: bold; color: #1a1a1a; letter-spacing: 0.5px; }
          .resume-title { font-size: 10pt; color: #333; margin-top: 3px; }
          .resume-contact { font-size: 9pt; color: #555; margin-top: 4px; }
          .divider { border: none; border-top: 1.5px solid #\(accent); margin: 12px 0 8px; }
          h2 { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1.2px; color: #\(accent); margin-bottom: 6px; }
          .section p { margin-bottom: 4px; font-size: 9.5pt; }
          .section ul { \(listIndent) }
          .section li { margin-bottom: 3px; font-size: 9.5pt; }
          .section br { display: block; margin: 2px 0; }
        </style>
        </head>
        <body>
        \(headerHTML)
        \(body)
        </body>
        </html>
        """
    }
}
