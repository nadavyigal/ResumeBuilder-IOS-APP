import Foundation
import PDFKit
import CoreText
import UIKit

struct UploadFileDescriptor: Sendable {
    let filename: String
    let data: Data
    let mimeType: String
    let resumeText: String?
}

enum UploadFilePreflightError: LocalizedError, Equatable, Sendable {
    case missingFile
    case emptyFile
    case unsupportedFileType
    case fileTooLarge(bytes: Int)
    case unreadablePDF

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return NSLocalizedString("Selected resume file could not be found. Please choose it again from Files.", comment: "")
        case .emptyFile:
            return NSLocalizedString("Selected resume file is empty. Please choose a freshly exported PDF.", comment: "")
        case .unsupportedFileType:
            return NSLocalizedString("Choose a PDF, DOCX, or DOC resume exported from your word processor.", comment: "")
        case .fileTooLarge:
            return NSLocalizedString("This file is larger than 5 MB. Export a smaller PDF or DOCX and try again.", comment: "")
        case .unreadablePDF:
            return NSLocalizedString("This PDF does not contain readable text. Re-export it from your word processor with File > Save As PDF, not a scan or screenshot.", comment: "")
        }
    }
}

enum UploadFilePreflight {
    nonisolated static func loadResumeFile(_ fileURL: URL) throws -> UploadFileDescriptor {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadFilePreflightError.missingFile
        }
        guard mimeType(for: fileURL) != nil else {
            throw UploadFilePreflightError.unsupportedFileType
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw UploadFilePreflightError.emptyFile
        }
        guard data.count <= 5_000_000 else {
            throw UploadFilePreflightError.fileTooLarge(bytes: data.count)
        }
        var uploadData = data
        var resumeText: String?
        if mimeType(for: fileURL) == "application/pdf" {
            let text = try readablePDFText(data)
            resumeText = text
            uploadData = try makeBackendReadablePDF(from: text)
        }
        return UploadFileDescriptor(
            filename: fileURL.lastPathComponent,
            data: uploadData,
            mimeType: mimeType(for: fileURL) ?? "application/octet-stream",
            resumeText: resumeText
        )
    }

    nonisolated static func mimeType(for fileURL: URL) -> String? {
        switch fileURL.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc":
            return "application/msword"
        default:
            return nil
        }
    }

    private nonisolated static func readablePDFText(_ data: Data) throws -> String {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw UploadFilePreflightError.unreadablePDF
        }

        var readableText = ""
        for pageIndex in 0..<document.pageCount {
            let text = document.page(at: pageIndex)?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                readableText += text + "\n\n"
            }
        }

        let trimmed = readableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw UploadFilePreflightError.unreadablePDF
        }
        return trimmed
    }

    private nonisolated static func makeBackendReadablePDF(from text: String) throws -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let textBounds = pageBounds.insetBy(dx: 54, dy: 54)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.paragraphSpacing = 8

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor.black,
            ]
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        return renderer.pdfData { context in
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            var currentIndex = 0
            let fullLength = attributed.length

            repeat {
                context.beginPage()
                guard let cgContext = UIGraphicsGetCurrentContext() else {
                    break
                }

                cgContext.saveGState()
                cgContext.textMatrix = .identity
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1, y: -1)

                let path = CGMutablePath()
                path.addRect(textBounds)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: currentIndex, length: fullLength - currentIndex),
                    path,
                    nil
                )
                CTFrameDraw(frame, cgContext)
                cgContext.restoreGState()

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                guard visibleRange.length > 0 else {
                    break
                }
                currentIndex += visibleRange.length
            } while currentIndex < fullLength
        }
    }
}
