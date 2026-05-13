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

    private let designService: any ResumeDesignServiceProtocol = BackendConfig.useMockServices
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
                resumeData: resumeDataForPreview()
            )
            let response = try await designService.renderPreview(request, token: token)
            if let previewHTML = response.previewHTML, !previewHTML.isEmpty {
                html = previewHTML
            } else {
                errorMessage = response.error ?? "Preview unavailable. Try downloading the PDF instead."
            }
        } catch {
            errorMessage = error.localizedDescription
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

    private func resumeDataForPreview() -> [String: JSONValue]? {
        guard !sections.isEmpty else { return nil }

        var resumeData: [String: JSONValue] = [:]
        for section in sections {
            let text = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            switch section.type {
            case .summary:
                resumeData["summary"] = .string(text)
            case .skills:
                resumeData["skills"] = .array(nonEmptyLines(in: text).map(JSONValue.string))
            case .experience:
                resumeData["experience"] = .array([
                    .object([
                        "title": .string("Experience"),
                        "achievements": .array(nonEmptyLines(in: text).map(JSONValue.string))
                    ])
                ])
            case .education:
                resumeData["education"] = .array([
                    .object([
                        "institution": .string(text)
                    ])
                ])
            case .additional:
                resumeData["certifications"] = .array(nonEmptyLines(in: text).map(JSONValue.string))
            }
        }

        return resumeData.isEmpty ? nil : resumeData
    }

    private func nonEmptyLines(in text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
