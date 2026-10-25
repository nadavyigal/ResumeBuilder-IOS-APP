import XCTest
@testable import ResumeBuilder_IOS_APP

/// Holds the saved-design request open until the test resumes it.
private final class SuspendedDesignService: ResumeDesignServiceProtocol, @unchecked Sendable {
    private var continuation: CheckedContinuation<DesignAssignmentDTO?, Error>?
    private(set) var assignmentCalls = 0

    func currentAssignment(optimizationId: String, token: String) async throws -> DesignAssignmentDTO? {
        assignmentCalls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func resume(with assignment: DesignAssignmentDTO?) {
        continuation?.resume(returning: assignment)
        continuation = nil
    }

    func templates(category: String, token: String) async throws -> [DesignTemplate] { [] }
    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        RenderPreviewResponse(success: true, previewHTML: nil, error: nil)
    }
    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        true
    }
}

/// Export must use the saved design even when the tap happens before that load finishes.
@MainActor
final class DesignExportSettingsTests: XCTestCase {
    func testExportWaitsForTheSavedDesignInsteadOfTheDefault() async {
        let service = SuspendedDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)
        let loading = Task { await viewModel.loadCurrentAssignment(token: "tok") }

        for _ in 0..<50 where service.assignmentCalls == 0 {
            await Task.yield()
        }
        XCTAssertEqual(service.assignmentCalls, 1)

        let exporting = Task { await viewModel.exportDesignSettings(token: "tok") }
        await Task.yield()
        XCTAssertEqual(service.assignmentCalls, 1, "export joins the load already running")

        service.resume(with: DesignAssignmentDTO(
            id: "assignment-1",
            optimizationId: "opt-1",
            template: DesignTemplate(
                id: "sidebar-ssr",
                slug: "sidebar-ssr",
                name: "Sidebar",
                description: "Saved design",
                category: "modern",
                isPremium: false,
                thumbnailURL: nil,
                atsScore: nil
            ),
            customization: .object([
                "accent_color": .string("112233"),
                "font_style": .string("classic"),
                "spacing": .number(0.8),
            ])
        ))

        let settings = await exporting.value
        await loading.value
        XCTAssertEqual(settings.templateId, "sidebar-ssr")
        XCTAssertEqual(settings.customization.accentColor, "112233")
        XCTAssertEqual(settings.customization.fontStyle, "classic")
        XCTAssertEqual(settings.customization.spacing, 0.8)
    }

    func testExportKeepsATemplateChosenAfterTheSavedDesignLoaded() async {
        let service = SuspendedDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)
        let loading = Task { await viewModel.loadCurrentAssignment(token: "tok") }
        for _ in 0..<50 where service.assignmentCalls == 0 {
            await Task.yield()
        }
        service.resume(with: DesignAssignmentDTO(
            id: "assignment-1",
            optimizationId: "opt-1",
            template: DesignTemplate(
                id: "sidebar-ssr",
                slug: "sidebar-ssr",
                name: "Sidebar",
                description: "Saved design",
                category: "modern",
                isPremium: false,
                thumbnailURL: nil,
                atsScore: nil
            ),
            customization: nil
        ))
        await loading.value

        viewModel.selectTemplate("ats-clean")
        let settings = await viewModel.exportDesignSettings(token: "tok")
        XCTAssertEqual(settings.templateId, "ats-clean")
        XCTAssertEqual(service.assignmentCalls, 1, "a finished load is not fetched again")
    }
}
