import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 1 of the export-package spec: expert output must survive the run that produced
/// it, so Export and Submit can read the same artifacts instead of regenerating them.
@MainActor
final class ExpertArtifactPersistenceTests: XCTestCase {
    private let optimizationId = "opt-artifacts-1"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.submitPackageRecordsKey)
        UserDefaults.standard.removeObject(forKey: AppState.optimizationJobURLsKey)
        super.tearDown()
    }

    // MARK: - AppState merge semantics

    func testRememberExpertArtifactsStoresCoverLetterAndSurvivesRelaunch() {
        let appState = AppState()
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "Dear Hiring Manager,\nI am excited to apply.",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 1
        )

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.coverLetterText, "Dear Hiring Manager,\nI am excited to apply.")
        XCTAssertEqual(record?.coverLetterRunId, "run-cl")
        XCTAssertEqual(record?.coverLetterSelectionIndex, 1)

        let reloaded = AppState()
        reloaded.bootstrap()
        XCTAssertEqual(reloaded.submitPackageRecord(for: optimizationId)?.coverLetterRunId, "run-cl")
    }

    func testScreeningWriteDoesNotEraseStoredCoverLetter() {
        let appState = AppState()
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "Letter body.",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0
        )
        appState.rememberExpertArtifacts(
            for: optimizationId,
            screeningAnswers: [
                SubmitPackageCachedScreeningAnswer(
                    id: 0,
                    question: "Why this role?",
                    answer: "Aligns with my goals.",
                    evidenceUsed: [],
                    confidenceNote: nil
                )
            ],
            screeningRunId: "run-screening"
        )

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.coverLetterText, "Letter body.")
        XCTAssertEqual(record?.coverLetterRunId, "run-cl")
        XCTAssertEqual(record?.screeningAnswers.count, 1)
        XCTAssertEqual(record?.screeningRunId, "run-screening")
    }

    func testCoverLetterWriteDoesNotEraseStoredScreeningAnswersOrJobURL() {
        let appState = AppState()
        appState.rememberSubmitPackage(
            for: optimizationId,
            sourceURLString: "https://jobs.example.com/123",
            coverLetterText: nil,
            screeningAnswers: [
                SubmitPackageCachedScreeningAnswer(
                    id: 0,
                    question: "Expected salary?",
                    answer: "Market rate.",
                    evidenceUsed: [],
                    confidenceNote: nil
                )
            ]
        )
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "Letter body.",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0
        )

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.sourceURLString, "https://jobs.example.com/123")
        XCTAssertEqual(record?.screeningAnswers.count, 1)
        XCTAssertEqual(record?.coverLetterText, "Letter body.")
    }

    /// An empty artifact must be indistinguishable from no artifact, or Export will
    /// advertise a cover letter it cannot produce.
    func testEmptyArtifactsCreateNoRecord() {
        let appState = AppState()
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "   \n ",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0,
            screeningAnswers: [],
            screeningRunId: "run-screening"
        )

        XCTAssertNil(appState.submitPackageRecord(for: optimizationId))
    }

    func testEmptyArtifactWriteLeavesAnExistingRecordIntact() {
        let appState = AppState()
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "Letter body.",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0
        )
        appState.rememberExpertArtifacts(for: optimizationId, coverLetterText: "")

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.coverLetterText, "Letter body.")
        XCTAssertEqual(record?.coverLetterRunId, "run-cl")
    }

    func testSignOutClearsStoredArtifacts() {
        let appState = AppState()
        appState.rememberExpertArtifacts(
            for: optimizationId,
            coverLetterText: "Letter body.",
            coverLetterRunId: "run-cl",
            coverLetterSelectionIndex: 0
        )
        appState.signOut()

        XCTAssertNil(appState.submitPackageRecord(for: optimizationId))
    }

    // MARK: - ExpertModesViewModel writes on run

    func testCompletedCoverLetterRunPersistsTheRecommendedVariant() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState)

        await vm.run(.coverLetterArchitect, token: "token")

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.coverLetterText, "Recommended letter body.")
        XCTAssertEqual(record?.coverLetterRunId, "run-cl")
        XCTAssertEqual(record?.coverLetterSelectionIndex, 1)
    }

    func testCompletedScreeningRunPersistsAnswers() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState)

        await vm.run(.screeningAnswerStudio, token: "token")

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.screeningRunId, "run-screening")
        XCTAssertEqual(record?.screeningAnswers.map(\.question), ["Why this role?", "Expected salary?"])
        XCTAssertEqual(record?.screeningAnswers.first?.answer, "Aligns with my goals.")
    }

    func testSwitchingCoverLetterVariantRewritesTheStoredText() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState)

        await vm.run(.coverLetterArchitect, token: "token")
        vm.setSelectedVariantIndex(0, for: .coverLetterArchitect)

        let record = appState.submitPackageRecord(for: optimizationId)
        XCTAssertEqual(record?.coverLetterText, "First letter body.")
        XCTAssertEqual(record?.coverLetterSelectionIndex, 0)
    }

    func testFailedRunPersistsNothing() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState, failing: true)

        await vm.run(.coverLetterArchitect, token: "token")

        XCTAssertNil(appState.submitPackageRecord(for: optimizationId))
    }

    /// A run that produces no cover-letter variants must not create a record either.
    func testEmptyCoverLetterOutputPersistsNothing() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState, emptyOutput: true)

        await vm.run(.coverLetterArchitect, token: "token")

        XCTAssertNil(appState.submitPackageRecord(for: optimizationId))
    }

    /// The workflows that rewrite the résumé itself have no standalone artifact to store.
    func testUnrelatedWorkflowPersistsNothing() async {
        let appState = AppState()
        let vm = makeViewModel(appState: appState)

        await vm.run(.atsOptimizationReport, token: "token")

        XCTAssertNil(appState.submitPackageRecord(for: optimizationId))
    }

    // MARK: - Helpers

    private func makeViewModel(
        appState: AppState,
        failing: Bool = false,
        emptyOutput: Bool = false
    ) -> ExpertModesViewModel {
        ExpertModesViewModel(
            optimizationId: optimizationId,
            resumeViewModel: nil,
            service: ExpertArtifactWorkflowSpy(failing: failing, emptyOutput: emptyOutput),
            appState: appState
        )
    }
}

@MainActor
private final class ExpertArtifactWorkflowSpy: ExpertWorkflowServiceProtocol, @unchecked Sendable {
    private let failing: Bool
    private let emptyOutput: Bool

    init(failing: Bool = false, emptyOutput: Bool = false) {
        self.failing = failing
        self.emptyOutput = emptyOutput
    }

    func run(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?,
        evidenceInputs: [String: JSONValue]
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        if failing { throw ExpertWorkflowServiceError.emptyRunId }

        let runId: String
        let output: String
        switch type {
        case .screeningAnswerStudio:
            runId = "run-screening"
            output = """
            "screening_answers":[
              {"question":"Why this role?","answer":"Aligns with my goals.","evidence_used":[]},
              {"question":"Expected salary?","answer":"Market rate.","evidence_used":[]}
            ]
            """
        case .coverLetterArchitect:
            runId = "run-cl"
            output = emptyOutput
                ? #""cover_letter_variants":[]"#
                : """
                "recommended_index":1,
                "cover_letter_variants":[
                  {"tone":"Direct","letter":"First letter body."},
                  {"tone":"Warm","letter":"Recommended letter body."}
                ]
                """
        default:
            runId = "run-ats"
            output = #""ats_report":{"recommended_keywords_to_add":["SwiftUI"]}"#
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
        selectedFields: [String]?,
        acceptScoreDecrease: Bool
    ) async throws -> ExpertWorkflowApplyResponseDTO {
        let json = """
        {"success":true,"workflow_type":"\(workflowType.rawValue)","updated_fields":[],"apply_mode":"default","selection_index":0}
        """
        return try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: Data(json.utf8))
    }
}
