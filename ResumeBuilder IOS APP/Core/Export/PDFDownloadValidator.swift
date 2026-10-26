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

    static func validatePDFData(_ data: Data, statusCode: Int, includes name: String? = nil) throws {
        guard (200...299).contains(statusCode) else {
            throw APIClientError.serverError(status: statusCode, message: "Download failed")
        }
        guard looksLikePDF(data) else {
            throw APIClientError.serverError(status: statusCode, message: "Download did not return a valid PDF")
        }
        guard let document = PDFDocument(data: data),
              document.pageCount > 0,
              let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw PDFValidationError.missingTextLayer
        }
        if let name, !pdfText(text, contains: name) {
            throw PDFValidationError.missingTextLayer
        }
    }

    static func validatePDF(at url: URL, includes name: String? = nil) throws {
        try validatePDFData(Data(contentsOf: url), statusCode: 200, includes: name)
    }

    /// True when every letter of `name` appears in the PDF text. Order does not
    /// matter, so a Hebrew name still counts when the extractor reverses it.
    /// An empty or punctuation-only name is not a requirement.
    static func pdfText(_ text: String, contains name: String) -> Bool {
        let needle = letterCounts(name)
        guard !needle.isEmpty else { return true }
        let haystack = letterCounts(text)
        return needle.allSatisfy { letter, count in (haystack[letter] ?? 0) >= count }
    }

    private static func letterCounts(_ text: String) -> [Character: Int] {
        var counts: [Character: Int] = [:]
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        for scalar in folded.unicodeScalars where CharacterSet.letters.contains(scalar) {
            let letter = Character(String(scalar))
            counts[letter, default: 0] += 1
        }
        return counts
    }
}
