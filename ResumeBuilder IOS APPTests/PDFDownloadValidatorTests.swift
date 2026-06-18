import XCTest
@testable import ResumeBuilder_IOS_APP

final class PDFDownloadValidatorTests: XCTestCase {
    func testLooksLikePDFAcceptsValidHeader() {
        let data = Data("%PDF-1.4\n%fake".utf8)
        XCTAssertTrue(PDFDownloadValidator.looksLikePDF(data))
    }

    func testLooksLikePDFRejectsHTML() {
        let data = Data("<html><body>not a pdf</body></html>".utf8)
        XCTAssertFalse(PDFDownloadValidator.looksLikePDF(data))
    }

    func testValidatePDFDataRejectsNonPDF() {
        let data = Data("not-a-pdf".utf8)
        XCTAssertThrowsError(try PDFDownloadValidator.validatePDFData(data, statusCode: 200)) { error in
            guard case APIClientError.serverError(let status, let message) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(status, 200)
            XCTAssertTrue(message.contains("valid PDF"))
        }
    }

    func testValidatePDFDataRejectsNonSuccessStatus() {
        let data = Data("%PDF-1.4".utf8)
        XCTAssertThrowsError(try PDFDownloadValidator.validatePDFData(data, statusCode: 500))
    }
}
