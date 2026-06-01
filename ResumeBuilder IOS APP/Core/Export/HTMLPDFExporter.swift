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
            let delegate = Delegate(optimizationId: optimizationId) { result in
                continuation.resume(with: result)
            }
            webView.navigationDelegate = delegate
            // Retain the delegate for the duration of the async operation.
            objc_setAssociatedObject(webView, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            webView.loadHTMLString(html, baseURL: BackendConfig.apiBaseURL)
        }
    }

    @MainActor
    private final class Delegate: NSObject, WKNavigationDelegate {
        private let optimizationId: String
        private var completion: ((Result<URL, Error>) -> Void)?

        init(optimizationId: String, completion: @escaping (Result<URL, Error>) -> Void) {
            self.optimizationId = optimizationId
            self.completion = completion
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.createPDF { [self] result in
                switch result {
                case .success(let data):
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Resume_\(self.optimizationId).pdf")
                    do {
                        try data.write(to: dest, options: .atomic)
                        self.completion?(.success(dest))
                    } catch {
                        self.completion?(.failure(error))
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                }
                self.completion = nil
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            completion?(.failure(error))
            completion = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            completion?(.failure(error))
            completion = nil
        }
    }
}
