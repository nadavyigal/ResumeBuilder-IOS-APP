import XCTest
import UIKit
@testable import ResumeBuilder_IOS_APP

@MainActor
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

    func testTheExportedTextMustContainTheResumeName() throws {
        let data = pdf(containing: "Dana Levi\nSenior iOS engineer")
        XCTAssertNoThrow(try PDFDownloadValidator.validatePDFData(data, statusCode: 200, includes: "Dana Levi"))
        XCTAssertThrowsError(try PDFDownloadValidator.validatePDFData(data, statusCode: 200, includes: "Other Person")) { error in
            XCTAssertTrue(error is PDFValidationError)
        }
    }

    func testAReversedHebrewNameStillCounts() {
        XCTAssertTrue(PDFDownloadValidator.pdfText("יאוי בדנ", contains: "נדב יואי"))
        XCTAssertTrue(PDFDownloadValidator.pdfText("Dana Levi", contains: "dana levi"))
        XCTAssertFalse(PDFDownloadValidator.pdfText("Hello", contains: "Dana Levi"))
    }

    func testAnEmptyNameDoesNotAddARequirement() throws {
        let data = pdf(containing: "Senior iOS engineer with Swift")
        XCTAssertNoThrow(try PDFDownloadValidator.validatePDFData(data, statusCode: 200, includes: " "))
    }

    private func pdf(containing text: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        return renderer.pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18)
            ])
        }
    }
}
