import XCTest
import UIKit
import PDFKit
@testable import ResumeBuilder_IOS_APP

@MainActor
final class LiveEndpointStabilizationTests: XCTestCase {
    func testDisabledResumeLibraryDoesNotCallService() async {
        let service = SpyResumeLibraryService()
        let vm = ResumeLibraryViewModel(service: service, isEnabled: false)

        await vm.load(token: "token")

        XCTAssertTrue(vm.isUnavailable)
        XCTAssertEqual(vm.errorMessage, "Resume Library is not available yet.")
        XCTAssertEqual(service.listCalls, 0)
    }

    func testPDFPreflightUsesPDFMimeType() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-\(UUID().uuidString).pdf")
        try Self.writeTextPDF("Resume text for extraction", to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let descriptor = try UploadFilePreflight.loadResumeFile(url)
        let uploadedPDFText = PDFDocument(data: descriptor.data)?.string ?? ""

        XCTAssertEqual(descriptor.filename, url.lastPathComponent)
        XCTAssertEqual(descriptor.mimeType, "application/pdf")
        XCTAssertFalse(descriptor.data.isEmpty)
        XCTAssertTrue(uploadedPDFText.contains("Resume text for extraction"))
    }

    func testEmptyPDFPreflightFailsBeforeUpload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).pdf")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try UploadFilePreflight.loadResumeFile(url)) { error in
            XCTAssertEqual(error as? UploadFilePreflightError, .emptyFile)
        }
    }

    func testUnreadablePDFPreflightFailsBeforeUpload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blank-\(UUID().uuidString).pdf")
        try Self.writeBlankPDF(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try UploadFilePreflight.loadResumeFile(url)) { error in
            XCTAssertEqual(error as? UploadFilePreflightError, .unreadablePDF)
        }
    }

    func testPreviewCancellationErrorsAreBenign() {
        XCTAssertTrue(PreviewRenderErrorPolicy.isBenignCancellation(CancellationError()))
        XCTAssertTrue(PreviewRenderErrorPolicy.isBenignCancellation(URLError(.cancelled)))
        XCTAssertFalse(PreviewRenderErrorPolicy.isBenignCancellation(URLError(.timedOut)))
    }

    private static func writeTextPDF(_ text: String, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
            ]
            text.draw(at: CGPoint(x: 72, y: 72), withAttributes: attributes)
        }
    }

    private static func writeBlankPDF(to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
        }
    }
}

private final class SpyResumeLibraryService: ResumeLibraryServiceProtocol, @unchecked Sendable {
    var listCalls = 0

    func listSavedResumes(token: String) async throws -> [SavedResume] {
        listCalls += 1
        return []
    }

    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-24T00:00:00Z", sizeBytes: nil)
    }

    func deleteResume(id: String, token: String) async throws {}

    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-24T00:00:00Z", sizeBytes: nil)
    }

    func downloadResumePDF(id: String, token: String) async throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(id).pdf")
    }
}
