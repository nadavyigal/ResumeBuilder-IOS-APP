import XCTest
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
        try Data("%PDF-1.7 test".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let descriptor = try UploadFilePreflight.loadResumeFile(url)

        XCTAssertEqual(descriptor.filename, url.lastPathComponent)
        XCTAssertEqual(descriptor.mimeType, "application/pdf")
        XCTAssertFalse(descriptor.data.isEmpty)
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

    func testPreviewCancellationErrorsAreBenign() {
        XCTAssertTrue(PreviewRenderErrorPolicy.isBenignCancellation(CancellationError()))
        XCTAssertTrue(PreviewRenderErrorPolicy.isBenignCancellation(URLError(.cancelled)))
        XCTAssertFalse(PreviewRenderErrorPolicy.isBenignCancellation(URLError(.timedOut)))
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
