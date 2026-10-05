import Foundation
import OSLog
import UIKit
import WebKit

private let htmlPDFLogger = Logger(subsystem: "ResumeBuilder", category: "HTMLPDFExporter")

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
                htmlPDFLogger.error("HTML PDF export timed out for optimization \(self.optimizationId, privacy: .public)")
                complete(.failure(HTMLPDFExporterError.timedOut))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.createPDF { [self] result in
                switch result {
                case .success(let data):
                    do {
                        let dest = try ExportFileStore.writePDFData(data, optimizationId: self.optimizationId)
                        self.complete(.success(dest))
                    } catch {
                        htmlPDFLogger.error("HTML PDF export failed to write PDF for optimization \(self.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        self.complete(.failure(error))
                    }
                case .failure(let error):
                    htmlPDFLogger.error("HTML PDF export createPDF failed for optimization \(self.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    self.complete(.failure(error))
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            htmlPDFLogger.error("HTML PDF export navigation failed for optimization \(self.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            complete(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            htmlPDFLogger.error("HTML PDF export provisional navigation failed for optimization \(self.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)")
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

enum ExportFileStore {
    static func writePDFData(_ data: Data, optimizationId: String) throws -> URL {
        let directory = try exportsDirectory()
        let destination = directory.appendingPathComponent("Resume_\(safeFilenameComponent(optimizationId)).pdf")
        try? FileManager.default.removeItem(at: destination)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static func exportsDirectory() throws -> URL {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ResumeBuilderExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func safeFilenameComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}

@MainActor
enum LocalResumePDFExporter {
    static func exportPDF(
        sections: [OptimizedResumeSection],
        contact: ResumeContact?,
        optimizationId: String
    ) throws -> URL {
        let renderableSections = sections.compactMap { section -> (type: ResumeSectionType, body: String)? in
            let body = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? nil : (section.type, body)
        }
        guard contact?.hasDisplayableValue == true || !renderableSections.isEmpty else {
            throw APIClientError.invalidResponse
        }

        // Hebrew résumés render right-to-left with right alignment.
        let isRTL = ResumeTextDirection.isRTL(sections: sections, contact: contact)
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48
        let contentWidth = pageBounds.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            var y = margin

            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacing: CGFloat = 8) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.lineSpacing = 2
                if isRTL {
                    paragraph.alignment = .right
                    paragraph.baseWritingDirection = .rightToLeft
                }
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph,
                ]
                let rect = text.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )

                if y + ceil(rect.height) > pageBounds.height - margin {
                    context.beginPage()
                    y = margin
                }

                text.draw(
                    with: CGRect(x: margin, y: y, width: contentWidth, height: ceil(rect.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                y += ceil(rect.height) + spacing
            }

            if let contact, contact.hasDisplayableValue {
                if let name = contact.name?.trimmedNonEmpty {
                    draw(name, font: .systemFont(ofSize: 24, weight: .bold), spacing: 4)
                }
                if let title = contact.title?.trimmedNonEmpty {
                    draw(title, font: .systemFont(ofSize: 14, weight: .medium), color: .darkGray, spacing: 4)
                }
                if !contact.contactLine.isEmpty {
                    draw(contact.contactLine, font: .systemFont(ofSize: 10), color: .darkGray, spacing: 18)
                }
            }

            for section in renderableSections {
                draw(section.type.displayName.uppercased(), font: .systemFont(ofSize: 12, weight: .bold), spacing: 5)
                draw(section.body, font: .systemFont(ofSize: 10), spacing: 16)
            }
        }

        return try ExportFileStore.writePDFData(data, optimizationId: optimizationId)
    }
}

enum HTMLPDFExporterError: LocalizedError, Sendable {
    case timedOut

    var errorDescription: String? {
        "PDF rendering timed out. Please try again."
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
