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
        XCTAssertEqual(settings?.templateId, "sidebar-ssr")
        XCTAssertEqual(settings?.customization.accentColor, "112233")
        XCTAssertEqual(settings?.customization.fontStyle, "classic")
        XCTAssertEqual(settings?.customization.spacing, 0.8)
    }

    /// Codex P2 on f817db3: the user saves a new design in the Design tab while
    /// the first load is still running. The refresh must not keep the old one.
    func testARefreshDuringTheFirstLoadFetchesTheNewlySavedDesign() async {
        let service = SuspendedDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)
        func assignment(_ templateId: String) -> DesignAssignmentDTO {
            DesignAssignmentDTO(
                id: "assignment-\(templateId)",
                optimizationId: "opt-1",
                template: DesignTemplate(
                    id: templateId, slug: templateId, name: templateId, description: "",
                    category: "modern", isPremium: false, thumbnailURL: nil, atsScore: nil
                ),
                customization: .object([:])
            )
        }
        let loading = Task { await viewModel.loadCurrentAssignment(token: "tok") }
        for _ in 0..<50 where service.assignmentCalls == 0 { await Task.yield() }
        XCTAssertEqual(service.assignmentCalls, 1)

        let refreshing = Task { await viewModel.loadCurrentAssignment(token: "tok", forceRefresh: true) }
        for _ in 0..<5 { await Task.yield() }
        service.resume(with: assignment("sidebar-ssr"))
        await loading.value
        for _ in 0..<50 where service.assignmentCalls < 2 { await Task.yield() }
        XCTAssertEqual(service.assignmentCalls, 2, "the refresh fetches again after the first load")
        service.resume(with: assignment("timeline-ssr"))
        await refreshing.value

        XCTAssertEqual(viewModel.selectedTemplateId, "timeline-ssr")
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
        XCTAssertEqual(settings?.templateId, "ats-clean")
        XCTAssertEqual(service.assignmentCalls, 1, "a finished load is not fetched again")
    }

    func testAnExpiredTokenIsRefreshedBeforeTheSavedDesignIsChosen() async {
        let service = UnauthorizedThenSavedDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)

        let settings = await viewModel.exportDesignSettings(token: "stale") { "fresh" }

        XCTAssertEqual(service.calls, 2)
        XCTAssertEqual(service.tokens, ["stale", "fresh"])
        XCTAssertEqual(settings?.templateId, "sidebar-ssr")
    }

    /// Codex P1 on d77b6a4: a guest has no session. Refreshing would sign them
    /// out (no refresh token) and wipe their local progress, so do not refresh.
    func testAGuestExportDoesNotRefreshTheSession() async {
        let service = SuspendedDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)
        var refreshed = false

        _ = await viewModel.exportDesignSettings(token: nil) {
            refreshed = true
            return nil
        }

        XCTAssertFalse(refreshed, "a sessionless export must not call the token refresh")
        XCTAssertEqual(service.assignmentCalls, 0)
    }

    /// Codex P2 on d77b6a4: when the saved design cannot be read, export gets
    /// no settings rather than the default template posing as the chosen one.
    func testAFailedSavedDesignReadGivesNoSettings() async {
        let service = AlwaysFailingDesignService()
        let viewModel = DesignViewModel(optimizationId: "opt-1", designService: service)

        let settings: (templateId: String?, customization: DesignCustomization)? =
            await viewModel.exportDesignSettings(token: "tok") { "fresh" }

        XCTAssertNil(settings, "an unavailable saved design is not the default design")
        XCTAssertEqual(service.calls, 2, "it still retries once with a fresh token")
    }
}

private final class AlwaysFailingDesignService: ResumeDesignServiceProtocol, @unchecked Sendable {
    private(set) var calls = 0

    func currentAssignment(optimizationId: String, token: String) async throws -> DesignAssignmentDTO? {
        calls += 1
        throw APIClientError.serverError(status: 500, message: "unavailable")
    }

    func templates(category: String, token: String) async throws -> [DesignTemplate] { [] }
    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        RenderPreviewResponse(success: true, previewHTML: nil, error: nil)
    }
    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        true
    }
}

private final class UnauthorizedThenSavedDesignService: ResumeDesignServiceProtocol, @unchecked Sendable {
    private(set) var tokens: [String] = []
    var calls: Int { tokens.count }

    func currentAssignment(optimizationId: String, token: String) async throws -> DesignAssignmentDTO? {
        tokens.append(token)
        if tokens.count == 1 { throw APIClientError.unauthorized }
        return DesignAssignmentDTO(
            id: "assignment-1",
            optimizationId: optimizationId,
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
        )
    }

    func templates(category: String, token: String) async throws -> [DesignTemplate] { [] }
    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        RenderPreviewResponse(success: true, previewHTML: nil, error: nil)
    }
    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        true
    }
}
