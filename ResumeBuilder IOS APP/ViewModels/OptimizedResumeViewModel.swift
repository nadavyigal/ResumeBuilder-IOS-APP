import Foundation
import Observation
import OSLog

struct ATSInsightRow: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let score: Int
    let reason: String
}

enum OptimizedResumeSaveState: Sendable, Equatable {
    case idle
    case saving
    case saved(SavedResume)
    case failed(String)
}

@Observable
@MainActor
final class OptimizedResumeViewModel {
    var sections: [OptimizedResumeSection]
    /// Source resume uploaded for optimize (passed through for parity with Chat metadata).
    var resumeId: String?
    var isRefining = false
    var isSaving = false
    var isRefreshingATS = false
    var isLoadingSections = false
    var errorMessage: String? = nil
    var pendingRefine: (original: String, suggested: String)? = nil
    var activeSectionId: String? = nil

    /// ATS scores passed in at init time (from the review apply response).
    var atsScoreBefore: Int?
    var atsScoreAfter: Int?
    /// Job context for the header card.
    var jobTitle: String?
    var company: String?
    var contact: ResumeContact?
    var atsBlockers: [ATSOptimizationBlocker] = []
    var keywordSuggestions: [ATSOptimizationBlocker] {
        atsBlockers.filter { $0.category.lowercased() == "keywords" }
    }
    var keywordPreviews: [String: [ChatAffectedField]] = [:]
    var keywordPreviewErrors: [String: String] = [:]
    var keywordsBeingPreviewed: Set<String> = []
    var keywordsBeingApproved: Set<String> = []
    var keywordsApproved: Set<String> = []
    var backendDiagnosis: ResumeDiagnosis?
    var jobURLString: String?
    var applicationId: String?
    var isImprovingATS = false
    /// Set when an expert run would have lowered the match score. Nothing has
    /// been applied while this is non-nil — the user decides.
    var pendingScoreDecrease: PendingScoreDecrease?
    /// The run behind `pendingScoreDecrease`, so accepting commits that run
    /// rather than paying to generate a new one.
    private var pendingImprovementRunId: String?
    var hasCompletedATSImprovement = false
    var atsUpliftMessage: String?
    var savedResumeState: OptimizedResumeSaveState = .idle

    private let optimizationId: String?
    private let optimizationService: any ResumeOptimizationServiceProtocol
    private let analysisService: any ResumeAnalysisServiceProtocol
    private let expertService: any ExpertWorkflowServiceProtocol
    private let chatService: any ChatMessaging
    private let libraryService: any ResumeLibraryServiceProtocol
    private let detailLoader: (String, String) async throws -> OptimizationDetailDTO
    private var didAttemptInitialSectionLoad: Bool
    private static let detailCache = OptimizationDetailCacheActor()

    init(
        optimizationId: String?,
        resumeId: String? = nil,
        sections: [OptimizedResumeSection] = [],
        atsScoreBefore: Int? = nil,
        atsScoreAfter: Int? = nil,
        jobTitle: String? = nil,
        company: String? = nil,
        contact: ResumeContact? = nil,
        jobURLString: String? = nil,
        optimizationService: any ResumeOptimizationServiceProtocol = RuntimeServices.resumeOptimizationService(),
        analysisService: any ResumeAnalysisServiceProtocol = RuntimeServices.resumeAnalysisService(),
        expertService: any ExpertWorkflowServiceProtocol = ExpertWorkflowService(),
        chatService: any ChatMessaging = ChatService(),
        libraryService: any ResumeLibraryServiceProtocol = ResumeLibraryService(),
        detailLoader: @escaping (String, String) async throws -> OptimizationDetailDTO = { optimizationId, token in
            try await RuntimeServices.sharedAPIClient.get(
                endpoint: .optimizationDetail(id: optimizationId),
                token: token
            )
        }
    ) {
        self.optimizationId = optimizationId
        self.resumeId = resumeId
        self.sections = sections
        self.atsScoreBefore = atsScoreBefore
        self.atsScoreAfter = atsScoreAfter
        self.jobTitle = jobTitle
        self.company = company
        self.contact = contact
        self.jobURLString = jobURLString
        self.optimizationService = optimizationService
        self.analysisService = analysisService
        self.expertService = expertService
        self.chatService = chatService
        self.libraryService = libraryService
        self.detailLoader = detailLoader
        self.didAttemptInitialSectionLoad = optimizationId == nil || !sections.isEmpty
    }

    /// Exposed for downstream tools (e.g. chat) that share the same optimization id.
    var optimizationIdentifier: String? { optimizationId }

    var hasVisibleAppliedChanges: Bool {
        sections.contains { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func restoreSavedResumeState(appState: AppState) {
        if let resume = appState.savedResumeRecord(for: optimizationId)?.resume {
            savedResumeState = .saved(resume)
        } else if case .saved = savedResumeState {
            savedResumeState = .idle
        }
    }

    func restoreATSImprovementState(appState: AppState) {
        hasCompletedATSImprovement = hasCompletedATSImprovement
            || appState.hasCompletedATSImprovement(for: optimizationId)
        if hasCompletedATSImprovement {
            if let optimizationId {
                appState.markATSImprovementComplete(for: optimizationId)
            }
            atsUpliftMessage = NSLocalizedString(
                "Fit improvement applied once. The score above is current for this resume.",
                comment: ""
            )
        }
    }

    func saveOptimizedResume(appState: AppState) async {
        guard let optimizationId, hasVisibleAppliedChanges else {
            savedResumeState = .failed(NSLocalizedString("Your optimized resume is not ready to save yet.", comment: ""))
            return
        }
        if appState.savedResumeRecord(for: optimizationId) != nil {
            restoreSavedResumeState(appState: appState)
            return
        }
        savedResumeState = .saving
        AnalyticsService.shared.track(.saveStarted(optimizationId: optimizationId))
        do {
            let resume = try await appState.callWithFreshToken { token in
                try await self.libraryService.saveResume(
                    id: optimizationId,
                    displayName: NSLocalizedString("Optimized Resume", comment: ""),
                    token: token
                )
            }
            appState.rememberSavedResume(resume, for: optimizationId)
            savedResumeState = .saved(resume)
            AnalyticsService.shared.track(.saveSuccess(optimizationId: optimizationId))
        } catch {
            savedResumeState = .failed(NSLocalizedString("Couldn’t save this resume. Your preview is still here — try again.", comment: ""))
            AnalyticsService.shared.track(
                .saveFailed(
                    optimizationId: optimizationId,
                    reason: FailureReason.reason(for: error),
                    errorCode: ExportFailureCode.code(for: error)
                )
            )
        }
    }

    var isAwaitingInitialSections: Bool {
        optimizationId != nil && sections.isEmpty && !didAttemptInitialSectionLoad
    }

    var atsStatusLabel: String {
        let score = fitJourney.currentDisplayedScore ?? 0
        if score >= 80 { return "High" }
        if score >= 70 { return "Strong" }
        if score >= 55 { return "Medium" }
        return "Low"
    }

    var atsStatusDescription: String {
        switch atsStatusLabel {
        case "High":
            return NSLocalizedString("Strong match for this role. Keep edits truthful before applying.", comment: "")
        case "Strong":
            return NSLocalizedString("Close to high. A focused keyword and metrics pass may lift it further.", comment: "")
        case "Medium":
            return NSLocalizedString("Useful foundation, but match blockers still need attention.", comment: "")
        default:
            return NSLocalizedString("Low match. Improve role keywords, title fit, metrics, and section coverage before submitting.", comment: "")
        }
    }

    /// Score after an expert pass, when one has run. Recorded separately so the
    /// journey can show experts as their own stage rather than overwriting the
    /// improved number.
    var atsScoreAfterExpert: Int?

    /// The user's fit as a journey with stages, not a single number.
    ///
    /// `.fit` is where the resume started against this job, `.improved` is the
    /// tailored rewrite, `.expert` is what expert passes added. FitJourney owns
    /// the rule that the displayed number never goes backwards, so no screen
    /// has to remember it (founder direction 2026-07-26).
    /// The score from the free match check the user ran before signing in.
    ///
    /// Read from the session store rather than passed in: this view model has
    /// ten construction sites and threading a baseline through all of them
    /// would be ten chances to forget one. See `FitJourney.baseline` for why
    /// the floor is needed even after the engine fixes.
    var freeCheckScore: Int? {
        // Look up by whichever identity this instance was built with. The
        // Optimized tab constructs with an optimizationId and no resumeId, so a
        // resume-only lookup found nothing and the floor never applied —
        // shipped-but-inert. HomeTabView carries the score across identities as
        // the journey mints them (WP-45 D7).
        FitBaselineStore.shared.baseline(for: optimizationId)
            ?? FitBaselineStore.shared.baseline(for: resumeId)
    }

    var fitJourney: FitJourney {
        FitJourney(
            fit: atsScoreBefore,
            improved: atsScoreAfter,
            expert: atsScoreAfterExpert,
            baseline: freeCheckScore
        )
    }

    /// The stage the user has reached, for labelling the score they can see.
    var currentFitStage: FitStage? { fitJourney.currentStage }

    /// The number to show right now. Never below anything already shown.
    var currentATSScore: Int {
        fitJourney.currentDisplayedScore ?? 0
    }

    /// Where the resume started, for the "you were here" end of the journey.
    var startingFitScore: Int? { fitJourney.displayedScore(at: .fit) }

    /// Total gain so far, never negative.
    var fitGainSoFar: Int? { fitJourney.totalGain }

    /// The smallest improvement worth showing as a before/after pair.
    ///
    /// Mirrors `MIN_MEANINGFUL_LIFT` in `src/lib/ats/lift.ts`. A moderated
    /// session on 2026-07-24 watched a user optimize and see "42 before,
    /// 44 after"; over 60 days, 24 of 59 optimizations ended at +4 or worse and
    /// 6 ended lower than they started. A pair like that reads as a promise the
    /// run did not keep (WP-45 S2/S8).
    static let minimumMeaningfulLift = 5

    var atsScoreDelta: Int? {
        guard let before = atsScoreBefore, let after = atsScoreAfter else { return nil }
        return after - before
    }

    /// Did this run actually improve on the resume the user started with?
    ///
    /// Nil when there is nothing to compare. The backend sends the same verdict
    /// on the optimization response; this is the local fallback so the rule
    /// holds even against an older response that predates that field.
    var hasMeaningfulLift: Bool? {
        guard let delta = atsScoreDelta else { return nil }
        return delta >= Self.minimumMeaningfulLift
    }

    /// Whether to render the before/after numbers at all.
    ///
    /// False does NOT mean hide the result — it means show what changed and
    /// what is still missing, without a numeric pair. The scores themselves are
    /// never rewritten, clamped, or floored; withholding is a display decision,
    /// and inflating the number would be the dishonest fix for the same
    /// complaint.
    var shouldDisplayScorePair: Bool {
        hasMeaningfulLift ?? false
    }

    var atsLowScoreExplanation: String? {
        guard currentATSScore < 55 else { return nil }
        let blockerTitles = atsBlockers
            .prefix(2)
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if blockerTitles.isEmpty {
            return NSLocalizedString("Still low because the resume needs stronger role alignment, measurable outcomes, keywords, and section coverage for this job.", comment: "")
        }
        let joined = blockerTitles.joined(separator: NSLocalizedString(" and ", comment: "list separator"))
        return String(format: NSLocalizedString("Still low because %@. Improve these before submitting.", comment: ""), joined)
    }

    var atsInsightRows: [ATSInsightRow] {
        let score = currentATSScore
        return [
            ATSInsightRow(
                id: "summary",
                title: NSLocalizedString("Summary", comment: ""),
                score: adjustedATSScore(base: score, penalty: hasATSBlocker(matching: ["summary", "headline", "title", "positioning"]) ? 14 : -8),
                reason: hasATSBlocker(matching: ["summary", "headline", "title", "positioning"])
                    ? NSLocalizedString("Needs tighter role positioning", comment: "")
                    : NSLocalizedString("Role positioning looks serviceable", comment: "")
            ),
            ATSInsightRow(
                id: "experience",
                title: NSLocalizedString("Experience", comment: ""),
                score: adjustedATSScore(base: score, penalty: hasATSBlocker(matching: ["experience", "impact", "achievement", "outcome"]) ? 10 : -14),
                reason: hasATSBlocker(matching: ["experience", "impact", "achievement", "outcome"])
                    ? NSLocalizedString("Add clearer outcomes and scope", comment: "")
                    : NSLocalizedString("Experience signals are carrying the match", comment: "")
            ),
            ATSInsightRow(
                id: "skills",
                title: NSLocalizedString("Skills", comment: ""),
                score: adjustedATSScore(base: score, penalty: hasATSBlocker(matching: ["skill", "keyword", "keywords", "term"]) ? 18 : -6),
                reason: hasATSBlocker(matching: ["skill", "keyword", "keywords", "term"])
                    ? NSLocalizedString("Missing role-specific keywords", comment: "")
                    : NSLocalizedString("Skill coverage is reasonably aligned", comment: "")
            ),
            ATSInsightRow(
                id: "keywords",
                title: NSLocalizedString("Keywords", comment: ""),
                score: adjustedATSScore(base: score, penalty: hasATSBlocker(matching: ["keyword", "ats", "required", "term"]) ? 20 : 0),
                reason: hasATSBlocker(matching: ["keyword", "ats", "required", "term"])
                    ? NSLocalizedString("Target terms from the job post are underused", comment: "")
                    : NSLocalizedString("Keyword coverage is not the main blocker", comment: "")
            ),
        ]
    }

    var atsRecommendedActions: [String] {
        let blockerActions = atsBlockers
            .prefix(3)
            .compactMap { blocker -> String? in
                let action = (blocker.suggestedAction ?? blocker.detail ?? blocker.title)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return action.isEmpty ? nil : action
            }
        if !blockerActions.isEmpty { return blockerActions }
        if currentATSScore < 55 {
            return [
                NSLocalizedString("Add missing role keywords where they are truthful.", comment: ""),
                NSLocalizedString("Rewrite the summary around the exact target role.", comment: ""),
                NSLocalizedString("Add measurable outcomes to the strongest experience bullets.", comment: ""),
            ]
        }
        return [
            NSLocalizedString("Run Improve match for a focused keyword and metrics pass.", comment: ""),
            NSLocalizedString("Review every edit for factual accuracy before submitting.", comment: ""),
        ]
    }

    var resumeDiagnosis: ResumeDiagnosis {
        ResumeDiagnosisMapper.make(
            backendDiagnosis: backendDiagnosis,
            matchScore: atsScoreBefore,
            potentialScore: atsScoreAfter,
            blockers: atsBlockers,
            sections: sections,
            jobTitle: jobTitle,
            company: company
        )
    }

    /// Plain text of all sections joined for clipboard copy.
    var plainTextResume: String {
        var blocks: [String] = []
        if let contact, contact.hasDisplayableValue {
            let header = [
                contact.name,
                contact.title,
                contact.contactLine.isEmpty ? nil : contact.contactLine,
            ]
            .compactMap { value -> String? in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: "\n")
            if !header.isEmpty { blocks.append(header) }
        }
        blocks.append(contentsOf: sections.map { "\($0.type.displayName.uppercased())\n\($0.body)" })
        return blocks.joined(separator: "\n\n")
    }

    /// Downloads the PDF for this optimization and returns a temp file URL for sharing.
    /// Note: analytics (.exportStarted / .exportSuccess / .exportFailed) are tracked by
    /// ResumeExportAction, not here, to avoid double-firing from callers that use that wrapper.
    func downloadPDF(appState: AppState) async throws -> URL {
        try await appState.callWithFreshToken { token in
            try await self.downloadPDF(with: token)
        }
    }

    func downloadPDF(token: String?) async throws -> URL {
        guard let optId = optimizationId else { throw APIClientError.invalidResponse }
        guard let token else {
            // Guests have no server session, so /api/download is never reachable — but the
            // sections/contact already loaded into this view model (from the apply response)
            // are enough to generate a local, unstyled, text-layer PDF with no network call.
            // Throwing .unauthorized here instead would wall off every guest export even
            // though nothing about producing this file actually requires a token.
            return try LocalResumePDFExporter.exportPDF(
                sections: sections,
                contact: contact,
                optimizationId: optId
            )
        }
        return try await downloadPDFWithLocalFallback(with: token, optimizationId: optId)
    }

    func refreshSubmitPackageContext(token: String?) async {
        guard let optId = optimizationId, let token else { return }
        do {
            try await loadSections(with: token, optimizationId: optId, useCache: false)
        } catch {
            // Package generation can still proceed with the currently loaded sections.
        }
    }

    private func downloadPDF(with token: String) async throws -> URL {
        guard let optId = optimizationId else { throw APIClientError.invalidResponse }
        return try await downloadPDFWithLocalFallback(with: token, optimizationId: optId)
    }

    private static let downloadLogger = Logger(subsystem: "ResumeBuilder", category: "APIClient")

    private func downloadPDF(with token: String, optimizationId optId: String) async throws -> URL {
        var components = URLComponents(url: BackendConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/download/\(optId)"
        components.queryItems = [URLQueryItem(name: "fmt", value: "pdf")]
        guard let url = components.url else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        Self.downloadLogger.info("HTTP start GET \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            Self.downloadLogger.error("HTTP invalid response for \(url.absoluteString)")
            throw APIClientError.invalidResponse
        }
        Self.downloadLogger.info("HTTP response status=\(http.statusCode) bytes=\(data.count)")
        if http.statusCode == 401 { throw APIClientError.unauthorized }
        if http.statusCode == 402 { throw APIClientError.paymentRequired }
        guard (200...299).contains(http.statusCode) else {
            let message = Self.downloadErrorMessage(from: data)
            Self.downloadLogger.error("HTTP failure status=\(http.statusCode) message=\(message)")
            throw APIClientError.serverError(status: http.statusCode, message: message)
        }
        try PDFDownloadValidator.validatePDFData(data, statusCode: http.statusCode)
        return try ExportFileStore.writePDFData(data, optimizationId: optId)
    }

    private func downloadPDFWithLocalFallback(with token: String, optimizationId optId: String) async throws -> URL {
        do {
            return try await downloadPDF(with: token, optimizationId: optId)
        } catch APIClientError.unauthorized {
            throw APIClientError.unauthorized
        } catch APIClientError.paymentRequired {
            throw APIClientError.paymentRequired
        } catch APIClientError.serverError(let status, let message) where (400...499).contains(status) {
            throw APIClientError.serverError(status: status, message: message)
        } catch {
            if sections.isEmpty {
                try? await loadSections(with: token, optimizationId: optId, useCache: false)
            }
            errorMessage = NSLocalizedString("Server PDF unavailable — generated a local copy from your resume sections.", comment: "")
            return try LocalResumePDFExporter.exportPDF(
                sections: sections,
                contact: contact,
                optimizationId: optId
            )
        }
    }

    private static func downloadErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            return error
        }
        let text = String(data: data, encoding: .utf8) ?? NSLocalizedString("Download failed", comment: "")
        let stripped = text
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? NSLocalizedString("Download failed", comment: "") : String(stripped.prefix(240))
    }

    /// Fetches sections + job context from the backend when sections are empty (e.g. navigated
    /// from OptimizationReviewView where the apply response contains only the optimizationId).
    func loadSections(appState: AppState) async {
        guard sections.isEmpty, !isLoadingSections, !didAttemptInitialSectionLoad else { return }
        didAttemptInitialSectionLoad = true
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.loadSections(with: token, useCache: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes sections from the backend even when the current screen already has content.
    func forceReloadSections(appState: AppState) async {
        guard !isLoadingSections else { return }
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.loadSections(with: token, useCache: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSections(token: String?) async {
        guard sections.isEmpty, !isLoadingSections, !didAttemptInitialSectionLoad, let optId = optimizationId, let token else { return }
        didAttemptInitialSectionLoad = true
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            try await loadSections(with: token, optimizationId: optId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSections(with token: String, useCache: Bool = true) async throws {
        guard let optId = optimizationId else { return }
        try await loadSections(with: token, optimizationId: optId, useCache: useCache)
    }

    private func loadSections(with token: String, optimizationId optId: String, useCache: Bool = true) async throws {
        if useCache, let cached = await Self.detailCache.value(for: optId) {
            apply(detail: cached)
            return
        }

        let detail = try await detailLoader(optId, token)
        await Self.detailCache.store(detail, for: optId)
        apply(detail: detail)
    }

    func apply(detail: OptimizationDetailDTO) {
        sections = detail.sections
        if let detailContact = detail.contact, detailContact.hasDisplayableValue {
            contact = detailContact
        }
        if jobTitle == nil { jobTitle = detail.jobTitle }
        if company == nil  { company  = detail.company  }
        // The review preview is a projection. The optimization detail is the
        // authoritative measurement of the document that was actually saved
        // after the user's selections. Preserve the immutable starting score,
        // but always replace the projected "after" value when the stored result
        // supplies one (43 -> projected 57 -> stored 64 on the 2026-08-08 run).
        if atsScoreBefore == nil { atsScoreBefore = detail.atsScoreBefore }
        if let storedScore = detail.atsScoreAfter { atsScoreAfter = storedScore }
        hasCompletedATSImprovement = hasCompletedATSImprovement || detail.atsImprovementApplied
        atsBlockers = detail.atsBlockers
        backendDiagnosis = detail.diagnosis
        if jobURLString == nil { jobURLString = detail.jobUrl }
        if applicationId == nil { applicationId = detail.applicationId }
    }

    /// Record the score an expert apply reported, on the stage it belongs to.
    ///
    /// This wrote unconditionally into `atsScoreAfter` — the *improved* stage —
    /// even when the caller was an expert pass. That overwrote what the tailored
    /// rewrite achieved with what the experts achieved, so the improved reading
    /// was wrong and the expert gain was invisible: the number had already been
    /// raised before `.expert` was recorded. When the follow-up rescan fails on
    /// credits, which `improveATS` explicitly expects, the expert score stayed
    /// mislabelled as the rewrite's. The founder's journey is fit → improved →
    /// expert as separate climbing stages, so the stage is the caller's to name
    /// (WP-45 D7).
    func applyExpertATSResult(
        _ applyResult: ExpertWorkflowApplyResponseDTO,
        recordingAs stage: FitStage = .improved
    ) {
        // `newAtsScore` only. The `atsImpact?.after` fallback that used to sit
        // here reads `ats_impact_estimate`, a field the language model is asked
        // to fill in across six expert prompts — so a failed or absent server
        // measurement silently promoted an invented number into the user's
        // score. No measurement means no update (WP-45 D8).
        guard let reported = applyResult.newAtsScore else { return }

        let score = reported.displayPercent
        switch stage {
        case .expert:
            atsScoreAfterExpert = score
        case .fit, .improved:
            atsScoreAfter = score
        }
    }

    func refineSection(sectionId: String, instruction: String, token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }
        isRefining = true
        activeSectionId = sectionId
        errorMessage = nil
        defer { isRefining = false }
        do {
            let request = RefineSectionRequest(sectionId: sectionId, instruction: instruction, optimizationId: optId)
            let response = try await optimizationService.refineSection(request, token: token)
            if response.success == true {
                pendingRefine = (original: response.original ?? "", suggested: response.suggested ?? "")
            } else {
                errorMessage = response.error ?? NSLocalizedString("Refine failed", comment: "")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRefine(sectionId: String, acceptedText: String, token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let section = sections.first(where: { $0.id == sectionId })
            let request = RefineSectionApplyRequest(
                sectionId: sectionId,
                sectionType: section?.type ?? .additional,
                optimizationId: optId,
                acceptedText: acceptedText,
                originalText: section?.body ?? ""
            )
            let ok = try await optimizationService.applySectionRefine(request, token: token)
            if ok, let idx = sections.firstIndex(where: { $0.id == sectionId }) {
                sections[idx].body = acceptedText
                sections[idx].status = "improved"
                backendDiagnosis = nil
                await Self.detailCache.remove(optId)
            } else if !ok {
                errorMessage = NSLocalizedString("We couldn't save that edit. Please try again.", comment: "")
            }
            pendingRefine = nil
            activeSectionId = nil
        } catch let apiError as APIClientError {
            switch apiError {
            case .serverError(let status, _) where status >= 500:
                errorMessage = String(format: NSLocalizedString("The server encountered an issue saving this change (%lld). Please try again later.", comment: ""), status)
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveManualEdit(sectionId: String, newText: String, token: String?) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let section = sections.first(where: { $0.id == sectionId })
            let request = RefineSectionApplyRequest(
                sectionId: sectionId,
                sectionType: section?.type ?? .additional,
                optimizationId: optId,
                acceptedText: newText,
                originalText: section?.body ?? ""
            )
            let ok = try await optimizationService.applySectionRefine(request, token: token)
            if ok, let idx = sections.firstIndex(where: { $0.id == sectionId }) {
                sections[idx].body = newText
                sections[idx].status = "edited"
                backendDiagnosis = nil
                await Self.detailCache.remove(optId)
            } else if !ok {
                errorMessage = NSLocalizedString("We couldn't save that edit. Please try again.", comment: "")
            }
        } catch let apiError as APIClientError {
            switch apiError {
            case .serverError(let status, _) where status >= 500:
                errorMessage = String(format: NSLocalizedString("The server encountered an issue saving this change (%lld). Please try again later.", comment: ""), status)
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh the Match Score.
    ///
    /// `stage` says which part of the journey the new measurement belongs to.
    /// FitJourney guarantees the displayed number never falls below what the
    /// user has already seen, whichever stage records it.
    func rescanATS(token: String?, recordingAs stage: FitStage = .improved) async {
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }

        isRefreshingATS = true
        defer { isRefreshingATS = false }

        do {
            let previouslyShown = currentATSScore
            let response = try await analysisService.rescan(optimizationId: optId, token: token)

            // The baseline is NOT updated here, and this is deliberate.
            //
            // The reasoning it replaces — "both sides come from the same rescan,
            // so they are on the same scale" — is true of the pair in isolation
            // and wrong for the journey. The user has already been shown a
            // starting number. Replacing it with a fresh measurement of the same
            // unchanged original means their starting point moves under them: a
            // real 2026-07-27 run went 39 at the fit check, then 29 after an
            // expert pass, because this line overwrote it. Nothing the user did
            // changed the original resume, so nothing may change its score.
            //
            // Comparability is preserved by fixing the baseline, not by
            // re-deriving it (WP-45 D8). A rescan that disagrees is recorded as
            // a diagnostic, not shown.
            if let original = response.originalScore, let known = atsScoreBefore, original != known {
                AnalyticsService.shared.track(
                    .improveScoreRegressed(previous: known, measured: original)
                )
            } else if atsScoreBefore == nil {
                // First measurement of this journey: there is no baseline to protect.
                atsScoreBefore = response.originalScore
            }

            // Which stage this measurement belongs to is the caller's to say.
            // A plain refresh re-measures the tailored rewrite; a refresh that
            // follows an expert pass is what the experts added, and the founder
            // wants those as separate, climbing stages.
            if let optimized = response.optimizedScore {
                if optimized < previouslyShown {
                    AnalyticsService.shared.track(
                        .improveScoreRegressed(previous: previouslyShown, measured: optimized)
                    )
                }
                switch stage {
                case .expert:
                    atsScoreAfterExpert = optimized
                case .fit, .improved:
                    atsScoreAfter = optimized
                }
            }
            backendDiagnosis = nil
        } catch {
            errorMessage = String(format: NSLocalizedString("Couldn't refresh the Match Score: %@", comment: ""), error.localizedDescription)
        }
    }

    func improveATS(token: String?, appState: AppState) async {
        guard !isImprovingATS, !hasCompletedATSImprovement else {
            atsUpliftMessage = NSLocalizedString(
                "Fit improvement applied once. The score above is current for this resume.",
                comment: ""
            )
            return
        }
        guard let token else {
            errorMessage = ResumeOptimizationError.missingToken.localizedDescription
            return
        }
        guard let optId = optimizationId else {
            errorMessage = ResumeOptimizationError.missingOptimizationId.localizedDescription
            return
        }

        isImprovingATS = true
        atsUpliftMessage = nil
        errorMessage = nil
        defer { isImprovingATS = false }

        do {
            let evidence: [String: JSONValue] = [
                "user_context": .string("Improve ATS blockers while preserving user facts. Do not invent tools, metrics, employers, education, or certifications.")
            ]
            let run = try await expertService.run(
                type: .atsOptimizationReport,
                optimizationId: optId,
                token: token,
                evidenceInputs: evidence
            )
            pendingImprovementRunId = run.runId
            let apply = try await expertService.apply(
                runId: run.runId,
                workflowType: .atsOptimizationReport,
                token: token,
                selectionIndex: nil,
                screeningSelectedIndices: nil,
                selectedFields: nil,
                acceptScoreDecrease: false
            )
            // Apply is non-idempotent. Persist completion immediately after the
            // server confirms it so a failed refresh can never invite a second
            // mutation of the same resume.
            hasCompletedATSImprovement = true
            appState.markATSImprovementComplete(for: optId)
            mergeExpertApply(workflowType: .atsOptimizationReport, output: run.output, applyResult: apply)
            // An expert pass's own reported score is the expert stage's, so it
            // stands even if the rescan below fails on credits.
            applyExpertATSResult(apply, recordingAs: .expert)
            await Self.detailCache.remove(optId)
            appState.resumeSectionsNeedRefresh = true
            var previewRefreshError: String?
            do {
                try await loadSections(with: token, optimizationId: optId, useCache: false)
            } catch {
                previewRefreshError = NSLocalizedString(
                    "Fit improvement was applied, but the resume preview could not refresh. Reopen Optimized to load the saved result.",
                    comment: ""
                )
            }
            appState.resumePreviewRefreshToken += 1
            // This refresh is the expert pass's result, so it lands on the
            // expert stage rather than overwriting what the rewrite achieved.
            await rescanATS(token: token, recordingAs: .expert)
            // Rescan failure (e.g. 402) is secondary — the expert improvement succeeded.
            // Clear any error rescanATS set so it doesn't mislead the user.
            errorMessage = previewRefreshError
            atsUpliftMessage = previewRefreshError == nil
                ? NSLocalizedString(
                    "Fit improvement applied once. The score above and resume preview are now current.",
                    comment: ""
                )
                : NSLocalizedString(
                    "Fit improvement applied once. The score above is current for this resume.",
                    comment: ""
                )
        } catch ExpertWorkflowServiceError.scoreWouldDecrease(let kept, let measured) {
            // Not a failure. The server scored the candidate résumé before
            // writing anything, found it worse, and applied nothing — so the
            // user still has exactly what they had. Offer the decision rather
            // than an error, and keep the run id so accepting can commit it
            // without paying for the run twice.
            pendingScoreDecrease = PendingScoreDecrease(
                runId: pendingImprovementRunId,
                kept: kept,
                measured: measured
            )
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Commits an expert run the user has been shown would lower their score.
    ///
    /// Re-applies the same run with the decision attached. Nothing was written
    /// the first time, so this is the only call that changes anything.
    func acceptPendingScoreDecrease(token: String?, appState: AppState) async {
        guard let pending = pendingScoreDecrease, let runId = pending.runId, let token,
              let optId = optimizationId else {
            pendingScoreDecrease = nil
            return
        }
        pendingScoreDecrease = nil
        isImprovingATS = true
        defer { isImprovingATS = false }

        do {
            let apply = try await expertService.apply(
                runId: runId,
                workflowType: .atsOptimizationReport,
                token: token,
                selectionIndex: nil,
                screeningSelectedIndices: nil,
                selectedFields: nil,
                acceptScoreDecrease: true
            )
            hasCompletedATSImprovement = true
            appState.markATSImprovementComplete(for: optId)
            applyExpertATSResult(apply, recordingAs: .expert)
            await Self.detailCache.remove(optId)
            appState.resumeSectionsNeedRefresh = true
            try? await loadSections(with: token, optimizationId: optId, useCache: false)
            appState.resumePreviewRefreshToken += 1
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardPendingScoreDecrease() {
        // Nothing to undo: the server never wrote anything.
        pendingScoreDecrease = nil
    }

    func previewKeyword(suggestionId: String, token: String?) async {
        guard let optId = optimizationId, let token else { return }
        guard keywordPreviews[suggestionId] == nil else { return }

        keywordsBeingPreviewed.insert(suggestionId)
        keywordPreviewErrors[suggestionId] = nil
        defer { keywordsBeingPreviewed.remove(suggestionId) }

        do {
            let dto = try await chatService.previewKeywordSuggestion(
                optimizationId: optId,
                suggestionId: suggestionId,
                token: token
            )
            keywordPreviews[suggestionId] = dto.affectedFields
        } catch let apiError as APIClientError {
            // Never surface a raw server error string as if it were content.
            // A 404 here reached the user on device as the literal words
            // "Suggestion not found" sitting inside the preview card, which
            // reads like broken advice rather than a stale item. It means the
            // suggestion can no longer be resolved — usually because the
            // optimization was rescored after this list was built — so say
            // that, and tell the user what to do about it.
            if case .serverError(let status, _) = apiError, status == 404 {
                keywordPreviewErrors[suggestionId] = NSLocalizedString(
                    "This suggestion is out of date. Refresh to get the current list.",
                    comment: "Shown when a keyword suggestion can no longer be previewed"
                )
            } else {
                keywordPreviewErrors[suggestionId] = apiError.userFacingMessage
            }
        } catch {
            keywordPreviewErrors[suggestionId] = error.localizedDescription
        }
    }

    func approveKeyword(suggestionId: String, token: String?) async {
        guard let optId = optimizationId, let token else { return }
        guard let fields = keywordPreviews[suggestionId] else { return }

        keywordsBeingApproved.insert(suggestionId)
        defer { keywordsBeingApproved.remove(suggestionId) }

        do {
            let dto = try await chatService.approveChange(
                optimizationId: optId,
                suggestionId: suggestionId,
                affectedFields: fields,
                token: token
            )
            mergeApproveSnapshot(dto.updatedResume)
            keywordsApproved.insert(suggestionId)
        } catch let apiError as APIClientError {
            keywordPreviewErrors[suggestionId] = apiError.userFacingMessage
        } catch {
            keywordPreviewErrors[suggestionId] = error.localizedDescription
        }
    }

    func rejectKeyword(suggestionId: String) {
        keywordPreviews[suggestionId] = nil
        keywordPreviewErrors[suggestionId] = nil
    }

    func rejectRefine() {
        pendingRefine = nil
        activeSectionId = nil
    }

    /// Mirrors optimistic updates after `/api/v1/expert-workflows/runs/:id/apply`.
    /// Always merges when the apply call succeeded — the output JSON shape is the signal.
    func mergeExpertApply(
        workflowType: ExpertWorkflowType,
        output: JSONValue,
        applyResult: ExpertWorkflowApplyResponseDTO
    ) {
        guard applyResult.success != false else { return }

        switch workflowType {
        case .fullResumeRewrite:
            guard case .object(let root) = output else { return }
            let rewritten = root["rewritten_resume"] ?? root["resume"]
            guard let rewritten else { return }
            if let rebuilt = ExpertResumeSectionMapping.sections(fromRewrittenResume: rewritten) {
                if applyResult.updatedFields.contains("entire_resume") || applyResult.updatedFields.isEmpty {
                    sections = rebuilt
                } else {
                    for section in rebuilt where applyResult.updatedFields.contains(fieldName(for: section.type)) {
                        patchSection(type: section.type, body: section.body)
                    }
                }
                backendDiagnosis = nil
            }
        case .achievementQuantifier:
            ExpertResumeSectionMapping.patchQuantifierBullets(into: &sections, output: output)
            backendDiagnosis = nil
        case .professionalSummaryLab:
            ExpertResumeSectionMapping.patchSummaryLab(into: &sections, output: output)
            backendDiagnosis = nil
        case .atsOptimizationReport:
            ExpertResumeSectionMapping.patchSkillsFromAtsReport(into: &sections, output: output)
            backendDiagnosis = nil
        case .coverLetterArchitect, .screeningAnswerStudio:
            break
        }
    }

    /// Applies `approve-change` payloads (`rewrite_data`-shaped snapshots) onto section bodies when strings are present.
    func mergeApproveSnapshot(_ snapshot: JSONValue?) {
        guard case .object(let dict) = snapshot else { return }
        if let txt = ResumeRewriteMerger.flattenSummary(dict["summary"]) {
            patchSection(type: .summary, body: txt)
        }
        if let txt = ResumeRewriteMerger.flattenSkills(dict["skills"]) {
            patchSection(type: .skills, body: txt)
        }
        if let txt = ResumeRewriteMerger.flattenExperience(dict["experience"]) {
            patchSection(type: .experience, body: txt)
        }
        if let txt = ResumeRewriteMerger.flattenEducation(dict["education"]) {
            patchSection(type: .education, body: txt)
        }
        if let txt = ResumeRewriteMerger.flattenString(dict["certifications"]) {
            patchSection(type: .additional, body: txt)
        }
    }

    private func patchSection(type: ResumeSectionType, body newBody: String) {
        guard let idx = sections.firstIndex(where: { $0.type == type }) else { return }
        sections[idx].body = newBody
        sections[idx].status = "improved"
        backendDiagnosis = nil
    }

    private func fieldName(for type: ResumeSectionType) -> String {
        switch type {
        case .summary:
            return "summary"
        case .experience:
            return "experience"
        case .skills:
            return "skills"
        case .education:
            return "education"
        case .additional:
            return "certifications"
        }
    }

    private func hasATSBlocker(matching keywords: [String]) -> Bool {
        atsBlockers.contains { blocker in
            let haystack = [
                blocker.category,
                blocker.title,
                blocker.detail,
                blocker.suggestedAction,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            return keywords.contains { haystack.contains($0.lowercased()) }
        }
    }

    private func adjustedATSScore(base: Int, penalty: Int) -> Int {
        min(100, max(0, base - penalty))
    }
}

private enum ResumeRewriteMerger {
    static func flattenString(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        default:
            return nil
        }
    }

    static func flattenSummary(_ val: JSONValue?) -> String? {
        flattenString(val)
    }

    static func flattenSkills(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .string(let s):
            return flattenString(.string(s))
        case .object(let obj):
            var lines: [String] = []
            if let technical = obj["technical"], case .array(let tech) = technical {
                lines.append(contentsOf: strings(from: tech))
            }
            if let softVal = obj["soft"], case .array(let soft) = softVal {
                lines.append(contentsOf: strings(from: soft))
            }
            let merged = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return merged.isEmpty ? nil : merged
        default:
            return nil
        }
    }

    static func flattenExperience(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .array(let rows):
            return rows.compactMap { flattenExperienceRow($0) }.joined(separator: "\n\n")
        default:
            return nil
        }
    }

    private static func flattenExperienceRow(_ row: JSONValue) -> String? {
        guard case .object(let o) = row else { return nil }
        let title =
            flattenString(o["title"])
                ?? flattenString(o["jobTitle"])
                ?? flattenString(o["role"])
        let company = flattenString(o["company"]) ?? flattenString(o["organization"])
        let parts = [title, company].compactMap { $0 }
        let head = parts.joined(separator: " • ")
        var bullets: [String] = []
        if let achievements = o["achievements"], case .array(let ach) = achievements {
            bullets = strings(from: ach).map { "• \($0)" }
        }
        if let desc = o["description"], let line = flattenString(desc) {
            bullets.insert(line, at: 0)
        }
        var linesOut: [String] = []
        if !head.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { linesOut.append(head) }
        linesOut.append(contentsOf: bullets)
        let body = linesOut.joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : body
    }

    static func flattenEducation(_ val: JSONValue?) -> String? {
        guard let val else { return nil }
        switch val {
        case .array(let rows):
            let text = rows.compactMap { row -> String? in
                guard case .object(let o) = row else { return nil }
                let school = flattenString(o["school"]) ?? flattenString(o["institution"]) ?? flattenString(o["name"])
                let degree = flattenString(o["degree"])
                let years = flattenString(o["years"]) ?? flattenString(o["period"])
                return [degree, school, years].compactMap { $0 }.joined(separator: " • ").nilIfEmpty
            }
            .joined(separator: "\n")
            return text.nilIfEmpty
        default:
            return flattenString(val)
        }
    }

    private static func strings(from values: [JSONValue]) -> [String] {
        values.compactMap { flattenString($0) }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

struct OptimizationDetailCache {
    private var storage: [String: OptimizationDetailDTO] = [:]
    private var order: [String] = []
    private let limit = 10

    func value(for key: String) -> OptimizationDetailDTO? {
        storage[key]
    }

    mutating func store(_ detail: OptimizationDetailDTO, for key: String) {
        storage[key] = detail
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    mutating func remove(_ key: String) {
        storage.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }
}

actor OptimizationDetailCacheActor {
    private var storage: [String: OptimizationDetailDTO] = [:]
    private var order: [String] = []
    private let limit = 10

    func value(for key: String) -> OptimizationDetailDTO? {
        storage[key]
    }

    func store(_ detail: OptimizationDetailDTO, for key: String) {
        storage[key] = detail
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    func remove(_ key: String) {
        storage.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }
}

/// An expert run that would lower the match score, awaiting the user's decision.
///
/// Nothing has been written while one of these exists: the server scores the
/// candidate résumé before persisting, precisely so declining costs nothing.
/// Résumé content has no revert, so this decision has to happen before the
/// rewrite lands, not after.
struct PendingScoreDecrease: Identifiable, Equatable, Sendable {
    let runId: String?
    /// The score the user keeps if they decline.
    let kept: Double?
    /// What the run measured.
    let measured: Double

    var id: String { "\(runId ?? "none"):\(measured)" }
    // `safeRoundedInt`, not `Int(_:)`: both values arrive as `Double` on the
    // apply response, so an out-of-range number from the backend would trap.
    // Deliberately unscaled, matching the sibling `before`/`after` fields on
    // `ExpertAtsImpactResult` and the message in `ExpertWorkflowService`.
    var keptPercent: Int { (kept ?? 0).safeRoundedInt ?? 0 }
    var measuredPercent: Int { measured.safeRoundedInt ?? 0 }
}
