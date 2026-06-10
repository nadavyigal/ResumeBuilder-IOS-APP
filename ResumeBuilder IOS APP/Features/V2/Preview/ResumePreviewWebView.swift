import SwiftUI
import WebKit

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
        let sectionKey = sections
            .map { "\($0.id):\($0.type.rawValue):\($0.status):\($0.body)" }
            .joined(separator: "|")
        let customizationKey = customization.map { "\($0.spacing):\($0.accentColor):\($0.fontStyle)" } ?? "default"
        let contactKey = contact.map { "\($0.name ?? ""):\($0.email ?? ""):\($0.phone ?? ""):\($0.location ?? ""):\($0.linkedin ?? "")" } ?? "no-contact"
        return "\(optimizationId)|\(templateId ?? "ats-clean")|\(customizationKey)|\(contactKey)|\(sectionKey.hashValue)"
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
                WebKitHTMLView(html: html, baseURL: BackendConfig.apiBaseURL)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(errorMessage ?? "Preview unavailable")
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
                errorMessage = "Sign in to preview your resume."
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
                resumeData: nil
            )
            let response = try await designService.renderPreview(request, token: token)
            #if DEBUG
            print("🎨 [PREVIEW] renderPreview response: html=\(response.previewHTML?.count ?? 0) chars error=\(response.error ?? "none")")
            #endif
            if let previewHTML = response.previewHTML, !previewHTML.isEmpty {
                #if DEBUG
                print("✅ [PREVIEW] using rendered HTML")
                #endif
                html = previewHTML
                renderedHTML.wrappedValue = previewHTML
                PreviewHTMLCache.store(previewHTML, for: key)
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
                errorMessage = response.error ?? "Preview unavailable. Try downloading the PDF instead."
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
        defer { isDownloadingPDF = false }
        // Use the already-rendered styled HTML when available so the exported PDF
        // includes the design template the user selected.
        if let styledHTML = html {
            do {
                let dest = try await HTMLPDFExporter.exportPDF(html: styledHTML, optimizationId: optimizationId)
                pdfURL = dest
                showSharePDF = true
                return
            } catch {
                // Fall through to backend download on failure.
            }
        }
        do {
            var components = URLComponents(url: BackendConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
            components.path = "/api/download/\(optimizationId)"
            components.queryItems = [URLQueryItem(name: "fmt", value: "pdf")]
            guard let url = components.url else { return }
            var request = URLRequest(url: url, timeoutInterval: 60)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            let dest = try ExportFileStore.writePDFData(data, optimizationId: optimizationId)
            pdfURL = dest
            showSharePDF = true
        } catch {
            // Non-fatal — user can still use the share from OptimizedResumeView
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

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedHTML != html else { return }
        context.coordinator.lastLoadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator {
        var lastLoadedHTML: String?
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

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: Georgia, serif; font-size: 10pt; color: #1a1a1a; background: #fff; padding: 36px 44px; line-height: 1.5; }
          .resume-header { text-align: center; padding-bottom: 10px; }
          .resume-name { font-size: 18pt; font-weight: bold; color: #1a1a1a; letter-spacing: 0.5px; }
          .resume-title { font-size: 10pt; color: #333; margin-top: 3px; }
          .resume-contact { font-size: 9pt; color: #555; margin-top: 4px; }
          .divider { border: none; border-top: 1.5px solid #\(accent); margin: 12px 0 8px; }
          h2 { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1.2px; color: #\(accent); margin-bottom: 6px; }
          .section p { margin-bottom: 4px; font-size: 9.5pt; }
          .section ul { margin-left: 16px; }
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
