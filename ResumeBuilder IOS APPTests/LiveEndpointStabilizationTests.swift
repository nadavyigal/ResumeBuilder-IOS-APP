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
        XCTAssertTrue(descriptor.resumeText?.contains("Resume text for extraction") == true)
        XCTAssertTrue(uploadedPDFText.contains("Resume text for extraction"))
    }

    func testMultipartUploadIncludesResumeTextFallback() {
        let descriptor = UploadFileDescriptor(
            filename: "resume.pdf",
            data: Data("%PDF text-layer".utf8),
            mimeType: "application/pdf",
            resumeText: "Readable resume text from PDFKit"
        )

        let body = MultipartUploadBodyBuilder.build(
            boundary: "Boundary-Test",
            uploadFile: descriptor,
            fields: [
                "jobDescription": "Build iOS apps",
                "jobDescriptionUrl": nil,
                "resumeText": descriptor.resumeText,
            ]
        )
        let bodyText = String(data: body, encoding: .utf8) ?? ""

        XCTAssertTrue(bodyText.contains("name=\"resume\"; filename=\"resume.pdf\""))
        XCTAssertTrue(bodyText.contains("Content-Type: application/pdf"))
        XCTAssertTrue(bodyText.contains("name=\"resumeText\""))
        XCTAssertTrue(bodyText.contains("Readable resume text from PDFKit"))
        XCTAssertFalse(bodyText.contains("name=\"jobDescriptionUrl\""))
    }

    func testDesignAssignmentBodyUsesBackendCamelCaseTemplateId() {
        let body = DesignApplyRequestBody.assignment(templateId: "ats-clean")

        XCTAssertEqual(body["templateId"] as? String, "ats-clean")
        XCTAssertNil(body["template_id"])
    }

    func testApplyDesignWaitsForTemplateLoad() async {
        let service = SpyResumeDesignService()
        let vm = DesignViewModel(optimizationId: "opt-123", designService: service)
        vm.selectedTemplateId = "ats-clean"
        vm.isLoading = true

        let didApply = await vm.applyDesign(token: "token")

        XCTAssertFalse(didApply)
        XCTAssertEqual(service.applyCalls, 0)
        XCTAssertEqual(vm.errorMessage, "Design templates are still loading. Try again in a moment.")
    }

    func testPreviewRequestPolicySkipsDuplicateSuccessfulKeys() {
        var policy = PreviewRequestPolicy()

        XCTAssertTrue(policy.shouldRender(key: "a"))
        policy.markStarted(key: "a")
        XCTAssertFalse(policy.shouldRender(key: "a"))
        policy.markFinished(key: "a", didRender: true)
        XCTAssertFalse(policy.shouldRender(key: "a"))
        XCTAssertTrue(policy.shouldRender(key: "b"))
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

    func testLocalPreviewUsesRealContactAndDoesNotFabricatePlaceholderIdentity() {
        let html = ResumeHTMLBuilder.build(
            sections: [
                OptimizedResumeSection(id: "summary", type: .summary, body: "Builds reliable iOS apps.", status: "optimized"),
            ],
            contact: ResumeContact(
                name: "Ada Lovelace",
                email: "ada@example.com",
                phone: nil,
                location: "London",
                title: "iOS Engineer",
                linkedin: nil,
                portfolio: nil
            ),
            customization: .default
        )

        XCTAssertTrue(html.contains("Ada Lovelace"))
        XCTAssertTrue(html.contains("ada@example.com | London"))
        XCTAssertFalse(html.contains("Your Name"))
        XCTAssertFalse(html.contains("email@example.com"))
    }

    func testDesignViewModelLoadsCurrentAssignmentCustomization() async {
        let service = SpyResumeDesignService()
        let vm = DesignViewModel(optimizationId: "opt-123", designService: service)

        await vm.loadCurrentAssignment(token: "token")

        XCTAssertEqual(vm.selectedTemplateId, "modern-template")
        XCTAssertEqual(vm.customization.accentColor, "22D3EE")
        XCTAssertEqual(vm.customization.fontStyle, "minimal")
        XCTAssertGreaterThan(vm.customization.spacing, 0.6)
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

private final class SpyResumeDesignService: ResumeDesignServiceProtocol, @unchecked Sendable {
    var applyCalls = 0

    func templates(category: String, token: String) async throws -> [DesignTemplate] {
        []
    }

    func currentAssignment(optimizationId: String, token: String) async throws -> DesignAssignmentDTO? {
        DesignAssignmentDTO(
            id: "assignment-1",
            optimizationId: optimizationId,
            template: DesignTemplate(
                id: "modern-template",
                slug: "modern-pro",
                name: "Modern Pro",
                description: "Modern",
                category: "modern",
                isPremium: false,
                thumbnailURL: nil,
                atsScore: 90
            ),
            customization: .object([
                "color_scheme": .object(["accent": .string("#22D3EE")]),
                "font_family": .object(["heading": .string("System UI"), "body": .string("System UI")]),
                "spacing": .object(["line_height": .string("1.65")]),
            ])
        )
    }

    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        RenderPreviewResponse(success: true, previewHTML: "<html></html>", error: nil)
    }

    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        applyCalls += 1
        return true
    }
}
