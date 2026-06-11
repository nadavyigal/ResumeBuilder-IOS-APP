import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class OptimizedResumeViewModelTests: XCTestCase {

    // MARK: - loadSections

    func testLoadSectionsIsNoOpWhenSectionsAlreadyPresent() async {
        let existing = OptimizedResumeSection(id: "s1", type: .summary, body: "Existing", status: "optimized")
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [existing],
            optimizationService: MockResumeOptimizationService()
        )
        // token is nil → guard fails, but sections are non-empty → guard fails first
        await vm.loadSections(token: "tok")
        XCTAssertEqual(vm.sections.count, 1, "Should not overwrite existing sections")
    }

    func testLoadSectionsIsNoOpWithNilToken() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            optimizationService: MockResumeOptimizationService()
        )
        XCTAssertTrue(vm.sections.isEmpty)
        await vm.loadSections(token: nil)
        // Guard exits early — no network call, no error
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSectionsIsNoOpWithNilOptimizationId() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: nil,
            optimizationService: MockResumeOptimizationService()
        )
        await vm.loadSections(token: "tok")
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - plainTextResume

    func testPlainTextResumeJoinsSections() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [
                OptimizedResumeSection(id: "s1", type: .summary, body: "Great engineer.", status: "optimized"),
                OptimizedResumeSection(id: "s2", type: .skills, body: "Swift, iOS", status: "optimized"),
            ],
            optimizationService: MockResumeOptimizationService()
        )
        let text = vm.plainTextResume
        XCTAssertTrue(text.contains("SUMMARY"))
        XCTAssertTrue(text.contains("Great engineer."))
        XCTAssertTrue(text.contains("SKILLS"))
        XCTAssertTrue(text.contains("Swift, iOS"))
    }

    func testLocalResumePDFExporterWritesValidPDFData() async throws {
        let url = try LocalResumePDFExporter.exportPDF(
            sections: [
                OptimizedResumeSection(id: "s1", type: .summary, body: "Great engineer.", status: "optimized"),
                OptimizedResumeSection(id: "s2", type: .skills, body: "Swift, iOS", status: "optimized"),
            ],
            contact: ResumeContact(
                name: "Alex Resume",
                email: "alex@example.com",
                phone: nil,
                location: "Tel Aviv",
                title: "iOS Engineer",
                linkedin: nil,
                portfolio: nil
            ),
            optimizationId: "opt-local-test"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.prefix(5), Data("%PDF-".utf8))
        XCTAssertGreaterThan(data.count, 100)
    }

    // MARK: - rejectRefine

    func testRejectRefineClearsPendingState() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            optimizationService: MockResumeOptimizationService()
        )
        vm.pendingRefine = (original: "old", suggested: "new")
        vm.activeSectionId = "s1"
        vm.rejectRefine()
        XCTAssertNil(vm.pendingRefine)
        XCTAssertNil(vm.activeSectionId)
    }

    // MARK: - manual edits

    func testSaveManualEditPersistsAndUpdatesSectionBody() async {
        let optimizationService = ManualEditOptimizationSpy(applyResult: true)
        let existing = OptimizedResumeSection(id: "s1", type: .summary, body: "Old body", status: "optimized")
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [existing],
            optimizationService: optimizationService,
            analysisService: ManualEditAnalysisSpy()
        )

        await vm.saveManualEdit(sectionId: "s1", newText: "New body", token: "tok")

        XCTAssertEqual(optimizationService.appliedRequests.count, 1)
        XCTAssertEqual(optimizationService.appliedRequests.first?.selection.sectionId, "s1")
        XCTAssertEqual(optimizationService.appliedRequests.first?.selection.field, "summary")
        XCTAssertEqual(optimizationService.appliedRequests.first?.selection.text, "Old body")
        XCTAssertEqual(optimizationService.appliedRequests.first?.optimizationId, "opt-1")
        XCTAssertEqual(optimizationService.appliedRequests.first?.suggestion, "New body")
        XCTAssertEqual(vm.sections.first?.body, "New body")
        XCTAssertEqual(vm.sections.first?.status, "edited")
        XCTAssertNil(vm.errorMessage)
    }

    func testSaveManualEditFailureLeavesBodyUnchangedAndSetsError() async {
        let optimizationService = ManualEditOptimizationSpy(error: APIClientError.invalidResponse)
        let existing = OptimizedResumeSection(id: "s1", type: .summary, body: "Old body", status: "optimized")
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [existing],
            optimizationService: optimizationService,
            analysisService: ManualEditAnalysisSpy()
        )

        await vm.saveManualEdit(sectionId: "s1", newText: "New body", token: "tok")

        XCTAssertEqual(vm.sections.first?.body, "Old body")
        XCTAssertEqual(vm.sections.first?.status, "optimized")
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSaveManualEditServerRejectLeavesBodyUnchangedAndSetsError() async {
        let optimizationService = ManualEditOptimizationSpy(applyResult: false)
        let existing = OptimizedResumeSection(id: "s1", type: .summary, body: "Old body", status: "optimized")
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [existing],
            optimizationService: optimizationService,
            analysisService: ManualEditAnalysisSpy()
        )

        await vm.saveManualEdit(sectionId: "s1", newText: "New body", token: "tok")

        XCTAssertEqual(vm.sections.first?.body, "Old body")
        XCTAssertEqual(vm.sections.first?.status, "optimized")
        XCTAssertNotNil(vm.errorMessage)
    }

    func testRescanATSUpdatesHeadlineScores() async {
        let analysisService = ManualEditAnalysisSpy(
            rescanResponse: ATSRescanResponse(success: true, optimizedScore: 91, originalScore: 72)
        )
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            atsScoreBefore: 70,
            atsScoreAfter: 80,
            optimizationService: MockResumeOptimizationService(),
            analysisService: analysisService
        )

        await vm.rescanATS(token: "tok")

        XCTAssertEqual(analysisService.rescannedOptimizationIds, ["opt-1"])
        XCTAssertEqual(vm.atsScoreBefore, 72)
        XCTAssertEqual(vm.atsScoreAfter, 91)
        XCTAssertNil(vm.errorMessage)
    }

    func testImproveATSRunsExpertWorkflowAndRefreshesScore() async {
        let analysisService = ManualEditAnalysisSpy(
            rescanResponse: ATSRescanResponse(success: true, optimizedScore: 88, originalScore: 61)
        )
        let expertService = SubmitExpertWorkflowSpy()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "tok", refreshToken: nil, userId: "user-1", email: nil)
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [OptimizedResumeSection(id: "skills", type: .skills, body: "Swift", status: "optimized")],
            atsScoreBefore: 61,
            atsScoreAfter: 72,
            optimizationService: MockResumeOptimizationService(),
            analysisService: analysisService,
            expertService: expertService
        )

        await vm.improveATS(token: "tok", appState: appState)

        XCTAssertEqual(expertService.runTypes, [.atsOptimizationReport])
        XCTAssertEqual(expertService.appliedRunIds, ["run-1"])
        XCTAssertEqual(expertService.appliedWorkflowTypes, [.atsOptimizationReport])
        XCTAssertEqual(analysisService.rescannedOptimizationIds, ["opt-1"])
        XCTAssertEqual(vm.atsScoreBefore, 61)
        XCTAssertEqual(vm.atsScoreAfter, 88)
        XCTAssertEqual(appState.resumePreviewRefreshToken, 1)
        XCTAssertEqual(vm.atsUpliftMessage, "ATS improvements applied. Review the resume before submitting.")
    }

    // MARK: - submit package

    func testApplicationCreateRequestBodyUsesBackendFieldNames() {
        let body = ApplicationCreateRequestBody.build(
            jobTitle: "iOS Engineer",
            companyName: "Acme",
            sourceURL: "https://example.com/job",
            status: "saved",
            optimizationId: "opt-1"
        )

        XCTAssertEqual(body["job_title"] as? String, "iOS Engineer")
        XCTAssertEqual(body["company_name"] as? String, "Acme")
        XCTAssertEqual(body["source_url"] as? String, "https://example.com/job")
        XCTAssertEqual(body["status"] as? String, "saved")
        XCTAssertEqual(body["optimization_id"] as? String, "opt-1")
    }

    func testApplicationCreateEnvelopeDecodesNestedApplication() throws {
        let json = """
        {
          "success": true,
          "application": {
            "id": "app-1",
            "job_title": "iOS Engineer",
            "company_name": "Acme",
            "status": "applied",
            "optimization_id": "opt-1"
          }
        }
        """

        let envelope = try JSONDecoder().decode(ApplicationCreateEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(envelope.application.id, "app-1")
        XCTAssertEqual(envelope.application.jobTitle, "iOS Engineer")
        XCTAssertEqual(envelope.application.companyName, "Acme")
        XCTAssertEqual(envelope.application.status, "applied")
        XCTAssertEqual(envelope.application.optimizationId, "opt-1")
    }

    func testOptimizeRequestBodyUsesStrongFaithfulMode() {
        let body = OptimizeRequestBody.build(resumeId: "resume-1", jobDescriptionId: "job-1")

        XCTAssertEqual(body["resumeId"] as? String, "resume-1")
        XCTAssertEqual(body["jobDescriptionId"] as? String, "job-1")
        XCTAssertEqual(body["optimization_mode"] as? String, "strong_faithful")
        let profile = body["quality_profile"] as? [String: Any]
        XCTAssertEqual(profile?["rewrite_depth"] as? String, "substantial")
        XCTAssertEqual(profile?["fact_policy"] as? String, "preserve_user_facts")
        XCTAssertEqual(profile?["require_major_section_improvements"] as? Bool, true)
    }

    func testOptimizationDetailDecodesATSBlockersAndApplicationContext() throws {
        let json = """
        {
          "sections": [],
          "job_title": "iOS Engineer",
          "company": "Acme",
          "ats_score_before": 52,
          "ats_score_after": 78,
          "job_url": "https://example.com/job",
          "application_id": "app-1",
          "ats_blockers": [
            {
              "id": "kw",
              "category": "keywords",
              "title": "Missing required cloud terms",
              "suggested_action": "Add AWS and CI/CD where truthful.",
              "estimated_gain": 8,
              "severity": "high"
            }
          ]
        }
        """

        let detail = try JSONDecoder().decode(OptimizationDetailDTO.self, from: Data(json.utf8))

        XCTAssertEqual(detail.jobTitle, "iOS Engineer")
        XCTAssertEqual(detail.jobUrl, "https://example.com/job")
        XCTAssertEqual(detail.applicationId, "app-1")
        XCTAssertEqual(detail.atsBlockers.count, 1)
        XCTAssertEqual(detail.atsBlockers.first?.category, "keywords")
        XCTAssertEqual(detail.atsBlockers.first?.estimatedGain, 8)
    }

    func testApplicationDetailEnvelopeDecodesEmbeddedCoverLetterReport() throws {
        let json = """
        {
          "success": true,
          "application": {
            "id": "app-1",
            "job_title": "iOS Engineer",
            "company_name": "Acme",
            "status": "applied",
            "optimization_id": "opt-1"
          },
          "expert_reports": [
            {
              "id": "report-1",
              "run_id": "run-1",
              "report_title": "Cover Letter",
              "workflow_type": "cover_letter_architect",
              "output_json": {
                "cover_letter_variants": [
                  { "letter": "Dear Hiring Manager,\\nI am excited to apply." }
                ]
              }
            }
          ]
        }
        """

        let envelope = try JSONDecoder().decode(ApplicationDetailEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(envelope.expertReports.count, 1)
        XCTAssertEqual(envelope.expertReports.first?.runId, "run-1")
        XCTAssertEqual(envelope.expertReports.first?.coverLetterText, "Dear Hiring Manager,\nI am excited to apply.")
    }

    func testSubmitApplicationPackageOrchestratesCreateCoverLetterAndTracking() async throws {
        let resumeURL = FileManager.default.temporaryDirectory.appendingPathComponent("resume-\(UUID().uuidString).pdf")
        try Data("%PDF phase 2".utf8).write(to: resumeURL)
        defer { try? FileManager.default.removeItem(at: resumeURL) }

        let resumeProvider = SubmitResumeProviderSpy(pdfURL: resumeURL)
        let applicationService = SubmitApplicationTrackingSpy()
        let expertService = SubmitExpertWorkflowSpy()
        let vm = SubmitApplicationViewModel(
            resumeProvider: resumeProvider,
            applicationService: applicationService,
            expertService: expertService
        )
        vm.jobTitle = "iOS Engineer"
        vm.companyName = "Acme"
        vm.sourceURLString = "https://example.com/job"
        vm.coverLetterContext = "Mention SwiftUI."

        await vm.submit(token: "tok")

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(resumeProvider.downloadCalls, 1)
        XCTAssertEqual(applicationService.createdRequests.count, 1)
        XCTAssertEqual(applicationService.createdRequests.first?.jobTitle, "iOS Engineer")
        XCTAssertEqual(applicationService.createdRequests.first?.optimizedResumeId, "opt-1")
        XCTAssertEqual(applicationService.attached.count, 1)
        XCTAssertEqual(applicationService.attached.first?.0, "app-1")
        XCTAssertEqual(applicationService.attached.first?.1, "opt-1")
        XCTAssertEqual(applicationService.markedAppliedIds, ["app-1"])
        // Both cover letter and screening run in parallel; spy returns cover_letter output for both.
        XCTAssertEqual(Set(expertService.runTypes), [.coverLetterArchitect, .screeningAnswerStudio])
        // Cover letter is applied; screening apply is skipped because spy output has no screening_answers.
        XCTAssertEqual(expertService.appliedRunIds, ["run-1"])
        XCTAssertEqual(expertService.appliedWorkflowTypes, [.coverLetterArchitect])
        XCTAssertEqual(applicationService.savedReports.count, 1)
        XCTAssertEqual(applicationService.savedReports.first?.0, "app-1")
        XCTAssertEqual(applicationService.savedReports.first?.1, "run-1")
        XCTAssertEqual(vm.package?.application.id, "app-1")
        XCTAssertEqual(vm.package?.resumePDFURL, resumeURL)
        XCTAssertEqual(vm.package?.coverLetterText, "Dear Hiring Manager,\nI am excited to apply.")
        XCTAssertEqual(vm.package?.screeningAnswers, [])
        XCTAssertEqual(vm.package?.jobURL?.absoluteString, "https://example.com/job")
    }

    func testSubmitApplicationPackageIncludesScreeningAnswersWhenPersistSucceeds() async throws {
        let resumeURL = FileManager.default.temporaryDirectory.appendingPathComponent("resume-\(UUID().uuidString).pdf")
        try Data("%PDF screening".utf8).write(to: resumeURL)
        defer { try? FileManager.default.removeItem(at: resumeURL) }

        let resumeProvider = SubmitResumeProviderSpy(pdfURL: resumeURL)
        let applicationService = SubmitApplicationTrackingSpy()
        let expertService = SubmitExpertWorkflowWithScreeningSpy()
        let vm = SubmitApplicationViewModel(
            resumeProvider: resumeProvider,
            applicationService: applicationService,
            expertService: expertService
        )
        vm.jobTitle = "iOS Engineer"
        vm.companyName = "Acme"

        await vm.submit(token: "tok")

        XCTAssertNil(vm.errorMessage)
        // Both workflows ran.
        XCTAssertEqual(Set(expertService.runTypes), [.coverLetterArchitect, .screeningAnswerStudio])
        // Both were applied in order.
        XCTAssertEqual(expertService.appliedRunIds, ["run-cl", "run-screening"])
        XCTAssertEqual(expertService.appliedWorkflowTypes, [.coverLetterArchitect, .screeningAnswerStudio])
        // Screening apply used original backend indices; entry at index 1 had empty answer → filtered.
        XCTAssertEqual(expertService.appliedScreeningIndices.first, [0, 2])
        // Both reports persisted.
        XCTAssertEqual(applicationService.savedReports.count, 2)
        // Package carries the two non-empty screening answers.
        XCTAssertEqual(vm.package?.screeningAnswers.count, 2)
        XCTAssertEqual(vm.package?.screeningAnswers.first?.question, "Why this role?")
        XCTAssertEqual(vm.package?.screeningAnswers.last?.question, "Expected salary?")
        XCTAssertEqual(vm.package?.screeningAnswers.last?.confidenceNote, "Market rate")
        XCTAssertEqual(vm.package?.coverLetterText, "Dear Hiring Manager,\nI am excited to apply.")
    }
}

@MainActor
private final class ManualEditOptimizationSpy: ResumeOptimizationServiceProtocol, @unchecked Sendable {
    var appliedRequests: [RefineSectionApplyRequest] = []
    private let applyResult: Bool
    private let error: Error?

    init(applyResult: Bool = true, error: Error? = nil) {
        self.applyResult = applyResult
        self.error = error
    }

    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
        OptimizeResponse(success: true, sections: [], optimizationId: "opt-1", error: nil)
    }

    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse {
        RefineSectionResponse(success: true, original: nil, suggested: nil, error: nil)
    }

    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool {
        if let error { throw error }
        appliedRequests.append(request)
        return applyResult
    }
}

@MainActor
private final class ManualEditAnalysisSpy: ResumeAnalysisServiceProtocol, @unchecked Sendable {
    var rescannedOptimizationIds: [String] = []
    private let rescanResponse: ATSRescanResponse

    init(rescanResponse: ATSRescanResponse? = nil) {
        let fallback = ATSRescanResponse(success: true, optimizedScore: 86, originalScore: 71)
        self.rescanResponse = rescanResponse ?? fallback
    }

    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        ResumeAnalysis(overall: 0, ats: 0, content: 0, design: 0, missingKeywords: [])
    }

    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement] {
        []
    }

    func rescan(optimizationId: String, token: String) async throws -> ATSRescanResponse {
        rescannedOptimizationIds.append(optimizationId)
        return rescanResponse
    }
}

@MainActor
private final class SubmitResumeProviderSpy: SubmitResumePDFProviding {
    let optimizationIdentifier: String? = "opt-1"
    var jobTitle: String? = "Existing Role"
    var company: String? = "Existing Co"
    var contact: ResumeContact? = nil
    var jobURLString: String? = nil
    var downloadCalls = 0
    private let pdfURL: URL

    init(pdfURL: URL) {
        self.pdfURL = pdfURL
    }

    func downloadPDF(token: String?) async throws -> URL {
        downloadCalls += 1
        return pdfURL
    }
}

@MainActor
private final class SubmitApplicationTrackingSpy: ApplicationTrackingServiceProtocol, @unchecked Sendable {
    var createdRequests: [ApplicationCreateRequest] = []
    var attached: [(String, String)] = []
    var markedAppliedIds: [String] = []
    var savedReports: [(String, String)] = []

    func listApplications(token: String?) async throws -> [ApplicationItem] { [] }

    func fetchDetail(id: String, token: String?) async throws -> ApplicationDetailEnvelope {
        ApplicationDetailEnvelope(success: true, application: createdApplication, htmlUrl: nil, jsonUrl: nil)
    }

    func createApplication(_ request: ApplicationCreateRequest, token: String?) async throws -> ApplicationItem {
        createdRequests.append(request)
        return createdApplication
    }

    func markApplied(id: String, token: String?) async throws {
        markedAppliedIds.append(id)
    }

    func attachOptimized(applicationId: String, optimizedResumeId: String, token: String?) async throws {
        attached.append((applicationId, optimizedResumeId))
    }

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

    private var createdApplication: ApplicationItem {
        ApplicationItem(
            id: "app-1",
            jobTitle: "iOS Engineer",
            companyName: "Acme",
            status: "applied",
            optimizationId: "opt-1"
        )
    }
}

@MainActor
private final class SubmitExpertWorkflowSpy: ExpertWorkflowServiceProtocol, @unchecked Sendable {
    var runTypes: [ExpertWorkflowType] = []
    var appliedRunIds: [String] = []
    var appliedWorkflowTypes: [ExpertWorkflowType] = []

    func run(type: ExpertWorkflowType, optimizationId: String, token: String?, evidenceInputs: [String: JSONValue]) async throws -> ExpertWorkflowRunCreateResponseDTO {
        runTypes.append(type)
        let output: String
        if type == .atsOptimizationReport {
            output = #""ats_report":{"recommended_keywords_to_add":["SwiftUI","CI/CD"],"keyword_placements":[{"keyword":"SwiftUI","section":"skills"}]}"#
        } else {
            output = #""cover_letter_variants":[{"tone":"Concise","letter":"Dear Hiring Manager,\nI am excited to apply."}]"#
        }
        let json = """
        {
          "workflow_type": "\(type.rawValue)",
          "run_id": "run-1",
          "status": "completed",
          "output": {
            \(output)
          }
        }
        """
        return try JSONDecoder().decode(ExpertWorkflowRunCreateResponseDTO.self, from: Data(json.utf8))
    }

    func getStatus(runId: String, token: String?) async throws -> ExpertWorkflowRunSnapshot {
        ExpertWorkflowRunSnapshot(runId: runId, status: "completed", workflowTypeRaw: ExpertWorkflowType.coverLetterArchitect.rawValue, output: .object([:]), missingEvidence: [])
    }

    func apply(runId: String, workflowType: ExpertWorkflowType, token: String?, selectionIndex: Int?, screeningSelectedIndices: [Int]?, selectedFields: [String]?) async throws -> ExpertWorkflowApplyResponseDTO {
        appliedRunIds.append(runId)
        appliedWorkflowTypes.append(workflowType)
        let json = """
        {
          "success": true,
          "workflow_type": "\(workflowType.rawValue)",
          "updated_fields": [],
          "apply_mode": "default",
          "selection_index": 0
        }
        """
        return try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: Data(json.utf8))
    }
}

/// Spy that returns real screening answers for .screeningAnswerStudio
/// (index 1 has an empty answer and will be filtered out; surviving IDs are [0, 2]).
@MainActor
private final class SubmitExpertWorkflowWithScreeningSpy: ExpertWorkflowServiceProtocol, @unchecked Sendable {
    var runTypes: [ExpertWorkflowType] = []
    var appliedRunIds: [String] = []
    var appliedWorkflowTypes: [ExpertWorkflowType] = []
    var appliedScreeningIndices: [[Int]] = []

    func run(type: ExpertWorkflowType, optimizationId: String, token: String?, evidenceInputs: [String: JSONValue]) async throws -> ExpertWorkflowRunCreateResponseDTO {
        runTypes.append(type)
        let runId: String
        let output: String
        switch type {
        case .screeningAnswerStudio:
            runId = "run-screening"
            output = """
            "screening_answers":[
              {"question":"Why this role?","answer":"Aligns with my goals.","evidence_used":[]},
              {"question":"Gap?","answer":"","evidence_used":[]},
              {"question":"Expected salary?","answer":"70k","evidence_used":[],"confidence_note":"Market rate"}
            ]
            """
        default:
            runId = "run-cl"
            output = #""cover_letter_variants":[{"tone":"Concise","letter":"Dear Hiring Manager,\nI am excited to apply."}]"#
        }
        let json = """
        {"workflow_type":"\(type.rawValue)","run_id":"\(runId)","status":"completed","output":{\(output)}}
        """
        return try JSONDecoder().decode(ExpertWorkflowRunCreateResponseDTO.self, from: Data(json.utf8))
    }

    func getStatus(runId: String, token: String?) async throws -> ExpertWorkflowRunSnapshot {
        ExpertWorkflowRunSnapshot(runId: runId, status: "completed", workflowTypeRaw: ExpertWorkflowType.coverLetterArchitect.rawValue, output: .object([:]), missingEvidence: [])
    }

    func apply(runId: String, workflowType: ExpertWorkflowType, token: String?, selectionIndex: Int?, screeningSelectedIndices: [Int]?, selectedFields: [String]?) async throws -> ExpertWorkflowApplyResponseDTO {
        appliedRunIds.append(runId)
        appliedWorkflowTypes.append(workflowType)
        if let idx = screeningSelectedIndices { appliedScreeningIndices.append(idx) }
        let json = """
        {"success":true,"workflow_type":"\(workflowType.rawValue)","updated_fields":[],"apply_mode":"default","selection_index":0}
        """
        return try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: Data(json.utf8))
    }
}
