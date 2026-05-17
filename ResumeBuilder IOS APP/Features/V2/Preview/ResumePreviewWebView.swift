import SwiftUI
import WebKit

struct ResumePreviewWebView: View {
    @Environment(AppState.self) private var appState
    let optimizationId: String
    let sections: [OptimizedResumeSection]
    var templateId: String? = nil
    var customization: DesignCustomization? = nil

    @State private var html: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pdfURL: URL?
    @State private var showSharePDF = false
    @State private var isDownloadingPDF = false

    private let designService: any ResumeDesignServiceProtocol =
        (BackendConfig.useMockServices || BackendConfig.useMockDesignService)
            ? MockResumeDesignService() : ResumeDesignService()

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
                        Task { await renderPreview() }
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
        .task {
            await renderPreview()
        }
        .sheet(isPresented: $showSharePDF, onDismiss: { pdfURL = nil }) {
            if let url = pdfURL {
                ShareSheet(items: [url]).ignoresSafeArea()
            }
        }
    }

    // MARK: - Private

    private func renderPreview() async {
        guard let token = appState.session?.accessToken else {
            errorMessage = "Sign in to preview your resume."
            isLoading = false
            return
        }
        isLoading = true
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
            if let previewHTML = response.previewHTML, !previewHTML.isEmpty {
                html = previewHTML
            } else if !sections.isEmpty {
                // Backend returned empty preview_html — build a readable preview from the
                // sections already loaded in memory so the user always sees something.
                html = ResumeHTMLBuilder.build(sections: sections, customization: customization)
            } else {
                errorMessage = response.error ?? "Preview unavailable. Try downloading the PDF instead."
            }
        } catch {
            // Network/server error — fall back to client-side rendering when sections exist.
            if !sections.isEmpty {
                html = ResumeHTMLBuilder.build(sections: sections, customization: customization)
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func downloadAndShare() async {
        guard let token = appState.session?.accessToken else { return }
        isDownloadingPDF = true
        defer { isDownloadingPDF = false }
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
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("Resume_\(optimizationId).pdf")
            try data.write(to: dest, options: .atomic)
            pdfURL = dest
            showSharePDF = true
        } catch {
            // Non-fatal — user can still use the share from OptimizedResumeView
        }
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

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

// MARK: - Client-side HTML builder

enum ResumeHTMLBuilder {
    /// Builds a printable resume HTML page from locally loaded sections.
    /// Used as fallback when the backend render-preview endpoint is unavailable.
    static func build(sections: [OptimizedResumeSection], customization: DesignCustomization?) -> String {
        let accent = customization?.accentColor ?? "6366F1"
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
          .divider { border: none; border-top: 1.5px solid #\(accent); margin: 12px 0 8px; }
          h2 { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1.2px; color: #\(accent); margin-bottom: 6px; }
          .section p { margin-bottom: 4px; font-size: 9.5pt; }
          .section ul { margin-left: 16px; }
          .section li { margin-bottom: 3px; font-size: 9.5pt; }
          .section br { display: block; margin: 2px 0; }
        </style>
        </head>
        <body>
        <hr class="divider">
        \(body)
        </body>
        </html>
        """
    }
}
