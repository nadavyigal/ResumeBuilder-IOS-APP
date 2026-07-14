import Foundation
import PDFKit

enum PDFValidationError: LocalizedError, Sendable {
    case missingTextLayer

    var errorDescription: String? {
        NSLocalizedString("The PDF has no selectable text. Please try exporting again.", comment: "")
    }
}

enum PDFDownloadValidator: Sendable {
    static func looksLikePDF(_ data: Data) -> Bool {
        data.prefix(5) == Data("%PDF-".utf8)
    }

    static func validatePDFData(_ data: Data, statusCode: Int) throws {
        guard (200...299).contains(statusCode) else {
            throw APIClientError.serverError(status: statusCode, message: "Download failed")
        }
        guard looksLikePDF(data) else {
            throw APIClientError.serverError(status: statusCode, message: "Download did not return a valid PDF")
        }
        guard let document = PDFDocument(data: data),
              document.pageCount > 0,
              document.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw PDFValidationError.missingTextLayer
        }
    }

    static func validatePDF(at url: URL) throws {
        try validatePDFData(Data(contentsOf: url), statusCode: 200)
    }
}
