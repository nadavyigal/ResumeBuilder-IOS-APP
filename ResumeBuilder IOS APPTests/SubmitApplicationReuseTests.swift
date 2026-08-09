import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 3 of the export-package spec: Submit consumes the expert output the user
/// already generated instead of paying to generate it a second time — which also stops
/// the two surfaces from disagreeing about what the cover letter says.
@MainActor
final class SubmitApplicationReuseTests: XCTestCase {
    /// `SubmitApplicationViewModel.resumeProvider` is `weak`, so the test must own the
    /// provider — an inline one dies before `submit` reads it and every assertion then
    /// fails on a nil package for the wrong reason.
    private var provider: ReuseResumeProvider!

    override func setUp() async throws {
        try await super.setUp()
        provider = ReuseResumeProvider()
    }

    func testStoredArtifactsAreReusedAndNothingIsRegenerated() async {
        let expert = ReuseExpertSpy()
        let vm = makeViewModel(expert: expert, stored: fullRecord)

        await vm.submit(token: "token")

        XCTAssertEqual(expert.runTypes, [], "a stored cover letter and answers means nothing to run")
        XCTAssertEqual(vm.package?.coverLetterText, "Stored letter body.")
        XCTAssertEqual(vm.package?.coverLetterRunId, "run-cl")
        XCTAssertEqual(vm.package?.coverLetterSelectionIndex, 2)
        XCTAssertEqual(vm.package?.screeningAnswers.map(\.question), ["Why this role?"])
        XCTAssertEqual(vm.package?.screeningRunId, "run-screening")
        XCTAssertNil(vm.errorMessage)
    }

    func testOnlyTheMissingArtifactIsGenerated() async {
        let expert = ReuseExpertSpy()
        let vm = makeViewModel(expert: expert, stored: coverLetterOnlyRecord)

        await vm.submit(token: "token")

        XCTAssertEqual(expert.runTypes, [.screeningAnswerStudio], "the stored letter is reused, the answers are not stored")
        XCTAssertEqual(vm.package?.coverLetterText, "Stored letter body.")
        XCTAssertEqual(vm.package?.screeningRunId, "run-screening-fresh")
        XCTAssertEqual(vm.package?.screeningAnswers.count, 1)
    }

    func testWithoutAStoredRecordBothWorkflowsStillRun() async {
        let expert = ReuseExpertSpy()
        let vm = makeViewModel(expert: expert, stored: nil)

        await vm.submit(token: "token")

        XCTAssertEqual(Set(expert.runTypes), [.coverLetterArchitect, .screeningAnswerStudio])
        XCTAssertEqual(vm.package?.coverLetterText, "Fresh letter body.")
        XCTAssertEqual(vm.package?.coverLetterRunId, "run-cl-fresh")
    }

    /// Typed notes are a request for a new letter. Reusing a stored one would silently
    /// throw the user's input away.
    func testTypedCoverLetterNotesForceARegeneration() async {
        let expert = ReuseExpertSpy()
        let vm = makeViewModel(expert: expert, stored: fullRecord)
        vm.coverLetterContext = "Mention the migration I led."

        await vm.submit(token: "token")

        XCTAssertEqual(expert.runTypes, [.coverLetterArchitect])
        XCTAssertEqual(vm.package?.coverLetterText, "Fresh letter body.")
        XCTAssertEqual(
            expert.lastEvidenceInputs?["user_context"]?.stringValue,
            "Mention the migration I led."
        )
        XCTAssertEqual(vm.package?.screeningAnswers.count, 1, "stored answers are still reused")
    }

    // MARK: - Saving

    func testSavingReusedPackageAppliesTheStoredRuns() async {
        let expert = ReuseExpertSpy()
        let tracking = ReuseTrackingSpy()
        let vm = makeViewModel(expert: expert, tracking: tracking, stored: fullRecord)

        await vm.submit(token: "token")
        await vm.savePackageToMe(token: "token")

        XCTAssertEqual(expert.appliedRunIds, ["run-cl", "run-screening"])
        XCTAssertEqual(tracking.savedReports.map(\.1), ["run-cl", "run-screening"])
        XCTAssertNotNil(vm.package?.application)
        XCTAssertNil(vm.errorMessage)
    }

    /// Records written before the run ids existed still carry usable text. The package
    /// must save, just without the server-side apply it has no run to apply.
    func testLegacyRecordWithoutRunIdsStillSaves() async {
        let expert = ReuseExpertSpy()
        let tracking = ReuseTrackingSpy()
        let vm = makeViewModel(expert: expert, tracking: tracking, stored: legacyRecord)

        await vm.submit(token: "token")
        await vm.savePackageToMe(token: "token")

        XCTAssertEqual(expert.runTypes, [], "text without a run id is still text")
        XCTAssertEqual(vm.package?.coverLetterText, "Legacy letter body.")
        XCTAssertNil(vm.package?.coverLetterRunId)
        XCTAssertEqual(expert.appliedRunIds, [], "there is no run to apply")
        XCTAssertEqual(tracking.createdRequests.count, 1, "the application is still created")
        XCTAssertNotNil(vm.package?.application)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Fixtures

    private var fullRecord: SubmitPackageCacheRecord {
        SubmitPackageCacheRecord(
            optimizationId: "opt-1",
            sourceURLString: "https://jobs.example.com/1",
            coverLetterText: "Stored letter body.",
            screeningAnswers: [storedAnswer],
            savedAt: Date(timeIntervalSinceReferenceDate: 0),
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 2,
            screeningRunId: "run-screening"
        )
    }

    private var coverLetterOnlyRecord: SubmitPackageCacheRecord {
        SubmitPackageCacheRecord(
            optimizationId: "opt-1",
            sourceURLString: nil,
            coverLetterText: "Stored letter body.",
            screeningAnswers: [],
            savedAt: Date(timeIntervalSinceReferenceDate: 0),
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0,
            screeningRunId: nil
        )
    }

    private var legacyRecord: SubmitPackageCacheRecord {
        SubmitPackageCacheRecord(
            optimizationId: "opt-1",
            sourceURLString: nil,
            coverLetterText: "Legacy letter body.",
            screeningAnswers: [storedAnswer],
            savedAt: Date(timeIntervalSinceReferenceDate: 0),
            coverLetterRunId: nil,
            coverLetterSelectionIndex: nil,
            screeningRunId: nil
        )
    }

    private var storedAnswer: SubmitPackageCachedScreeningAnswer {
        SubmitPackageCachedScreeningAnswer(
            id: 0,
            question: "Why this role?",
            answer: "It matches my work.",
            evidenceUsed: [],
            confidenceNote: nil
        )
    }

    private func makeViewModel(
        expert: ReuseExpertSpy,
        tracking: ReuseTrackingSpy = ReuseTrackingSpy(),
        stored: SubmitPackageCacheRecord?
    ) -> SubmitApplicationViewModel {
        SubmitApplicationViewModel(
            resumeProvider: provider,
            applicationService: tracking,
            expertService: expert,
            storedArtifacts: stored
        )
    }
}

@MainActor
private final class ReuseResumeProvider: SubmitResumePDFProviding {
    var optimizationIdentifier: String? = "opt-1"
    var jobTitle: String? = "iOS Engineer"
    var company: String? = "Acme"
    var contact: ResumeContact? = nil
    var jobURLString: String? = "https://jobs.example.com/1"

    func refreshSubmitPackageContext(token: String?) async {}

    func downloadPDF(token: String?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("submit-reuse-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4 stub".utf8).write(to: url)
        return url
    }
}

private final class ReuseExpertSpy: ExpertWorkflowServiceProtocol, @unchecked Sendable {
    var runTypes: [ExpertWorkflowType] = []
    var appliedRunIds: [String] = []
    var lastEvidenceInputs: [String: JSONValue]?

    func run(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?,
        evidenceInputs: [String: JSONValue]
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        runTypes.append(type)
        if type == .coverLetterArchitect { lastEvidenceInputs = evidenceInputs }

        let runId: String
        let output: String
        switch type {
        case .screeningAnswerStudio:
            runId = "run-screening-fresh"
            output = #""screening_answers":[{"question":"Fresh question?","answer":"Fresh answer.","evidence_used":[]}]"#
        default:
            runId = "run-cl-fresh"
            output = #""cover_letter_variants":[{"tone":"Direct","letter":"Fresh letter body."}]"#
        }
        let json = """
        {"workflow_type":"\(type.rawValue)","run_id":"\(runId)","status":"completed","output":{\(output)}}
        """
        return try JSONDecoder().decode(ExpertWorkflowRunCreateResponseDTO.self, from: Data(json.utf8))
    }

    func getStatus(runId: String, token: String?) async throws -> ExpertWorkflowRunSnapshot {
        ExpertWorkflowRunSnapshot(
            runId: runId,
            status: "completed",
            workflowTypeRaw: ExpertWorkflowType.coverLetterArchitect.rawValue,
            output: .object([:]),
            missingEvidence: []
        )
    }

    func apply(
        runId: String,
        workflowType: ExpertWorkflowType,
        token: String?,
        selectionIndex: Int?,
        screeningSelectedIndices: [Int]?,
        selectedFields: [String]?
    ) async throws -> ExpertWorkflowApplyResponseDTO {
        appliedRunIds.append(runId)
        let json = """
        {"success":true,"workflow_type":"\(workflowType.rawValue)","updated_fields":[],"apply_mode":"default","selection_index":0}
        """
        return try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: Data(json.utf8))
    }
}

/// `@MainActor` because it constructs `ApplicationItem`, whose initializer is
/// MainActor-isolated under this project's default isolation (tasks/lessons.md 2026-06-02).
@MainActor
private final class ReuseTrackingSpy: ApplicationTrackingServiceProtocol, @unchecked Sendable {
    var createdRequests: [ApplicationCreateRequest] = []
    var savedReports: [(String, String)] = []

    func listApplications(token: String?) async throws -> [ApplicationItem] { [] }

    func fetchDetail(id: String, token: String?) async throws -> ApplicationDetailEnvelope {
        ApplicationDetailEnvelope(success: true, application: created, htmlUrl: nil, jsonUrl: nil)
    }

    func createApplication(_ request: ApplicationCreateRequest, token: String?) async throws -> ApplicationItem {
        createdRequests.append(request)
        return created
    }

    func markApplied(id: String, token: String?) async throws {}

    func attachOptimized(applicationId: String, optimizedResumeId: String, token: String?) async throws {}

    func fetchExpertReports(applicationId: String, token: String?) async throws -> [ApplicationExpertReportItem] { [] }

    func saveExpertReport(applicationId: String, runId: String, token: String?) async throws -> ApplicationExpertReportItem {
        savedReports.append((applicationId, runId))
        return ApplicationExpertReportItem(
            id: "report-1",
            reportTitle: "Cover Letter",
            workflowType: ExpertWorkflowType.coverLetterArchitect.rawValue,
            savedAt: nil
        )
    }

    private var created: ApplicationItem {
        ApplicationItem(
            id: "app-1",
            jobTitle: "iOS Engineer",
            companyName: "Acme",
            status: "saved",
            optimizationId: "opt-1"
        )
    }
}
