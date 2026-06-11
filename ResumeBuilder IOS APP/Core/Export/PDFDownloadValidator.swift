import Foundation

enum PDFDownloadValidator {
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
    }
}
