import XCTest
import PDFKit
import UIKit
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ScanViewModelTests: XCTestCase {
    func testHandlePickedPDFCachesWithPdfExtension() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-\(UUID().uuidString).pdf")
        try writeTextPDF("Scan resume text", to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let vm = ScanViewModel(uploadService: SpyResumeUploadService())
        await vm.handlePickedFile(url: source, token: nil)

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.detectedFilename, source.lastPathComponent)
        XCTAssertEqual(vm.selectedFileURL?.lastPathComponent, "cached_resume.pdf")
    }

    func testHandlePickedUnsupportedExtensionShowsError() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-\(UUID().uuidString).txt")
        try "plain text".write(to: source, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: source) }

        let vm = ScanViewModel(uploadService: SpyResumeUploadService())
        await vm.handlePickedFile(url: source, token: nil)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.selectedFileURL)
    }

    func testDocxMimeTypeRecognizedByPreflight() {
        let url = URL(fileURLWithPath: "/tmp/resume.docx")
        XCTAssertEqual(
            UploadFilePreflight.mimeType(for: url),
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }

    private func writeTextPDF(_ text: String, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: pageBounds.insetBy(dx: 40, dy: 40), withAttributes: attrs)
        }
        try data.write(to: url)
        XCTAssertNotNil(PDFDocument(url: url))
    }
}

private struct SpyResumeUploadService: ResumeUploadServiceProtocol {
    func upload(
        fileURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        token: String
    ) async throws -> ResumeUploadResponse {
        ResumeUploadResponse(
            success: true,
            resumeId: "r1",
            jobDescriptionId: "jd1",
            reviewId: nil,
            nextStep: nil,
            matchScore: nil,
            keyImprovements: nil,
            missingKeywords: nil,
            error: nil
        )
    }

    func publicATS(
        fileURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        sessionId: String?
    ) async throws -> ATSScoreResult {
        ATSScoreResult(
            success: true,
            score: ATSScoreResult.ScorePayload(overall: 70, timestamp: nil),
            preview: nil,
            quickWins: nil,
            checksRemaining: nil,
            sessionId: nil,
            error: nil
        )
    }
}
