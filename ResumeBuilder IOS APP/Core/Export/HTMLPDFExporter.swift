import Foundation
import WebKit

/// Renders styled HTML in an off-screen WKWebView and exports it as a PDF file.
///
/// Used when the backend's /api/download endpoint returns an unstyled PDF — the
/// render-preview HTML already has the design template applied, so we generate the PDF
/// client-side from that HTML instead.
@MainActor
enum HTMLPDFExporter {
    private static var delegateKey: UInt8 = 0

    static func exportPDF(html: String, optimizationId: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // A4 in points (72 dpi): 595 × 842
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842))
            let delegate = Delegate(webView: webView, optimizationId: optimizationId) { result in
                continuation.resume(with: result)
            }
            webView.navigationDelegate = delegate
            // Retain the delegate for the duration of the async operation.
            objc_setAssociatedObject(webView, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            delegate.startTimeout()
            webView.loadHTMLString(html, baseURL: BackendConfig.apiBaseURL)
        }
    }

    @MainActor
    private final class Delegate: NSObject, WKNavigationDelegate {
        private var webView: WKWebView?
        private let optimizationId: String
        private var completion: ((Result<URL, Error>) -> Void)?
        private var timeoutTask: Task<Void, Never>?

        init(webView: WKWebView, optimizationId: String, completion: @escaping (Result<URL, Error>) -> Void) {
            self.webView = webView
            self.optimizationId = optimizationId
            self.completion = completion
        }

        func startTimeout() {
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(20))
                complete(.failure(HTMLPDFExporterError.timedOut))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.createPDF { [self] result in
                switch result {
                case .success(let data):
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Resume_\(self.optimizationId).pdf")
                    do {
                        try data.write(to: dest, options: .atomic)
                        self.complete(.success(dest))
                    } catch {
                        self.complete(.failure(error))
                    }
                case .failure(let error):
                    self.complete(.failure(error))
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            complete(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            complete(.failure(error))
        }

        private func complete(_ result: Result<URL, Error>) {
            guard let completion else { return }
            self.completion = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            webView?.stopLoading()
            webView?.navigationDelegate = nil
            if let webView {
                objc_setAssociatedObject(webView, &HTMLPDFExporter.delegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            webView = nil
            completion(result)
        }
    }
}

enum HTMLPDFExporterError: LocalizedError, Sendable {
    case timedOut

    var errorDescription: String? {
        "PDF rendering timed out. Please try again."
    }
}
