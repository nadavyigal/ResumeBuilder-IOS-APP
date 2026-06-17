import Foundation
import Observation
import OSLog

struct ATSInsightRow: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let score: Int
    let reason: String
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
    var backendDiagnosis: ResumeDiagnosis?
    var jobURLString: String?
    var applicationId: String?
    var isImprovingATS = false
    var atsUpliftMessage: String?

    private let optimizationId: String?
    private let optimizationService: any ResumeOptimizationServiceProtocol
    private let analysisService: any ResumeAnalysisServiceProtocol
    private let expertService: any ExpertWorkflowServiceProtocol
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
        optimizationService: any ResumeOptimizationServiceProtocol = RuntimeServices.resumeOptimizationService(),
        analysisService: any ResumeAnalysisServiceProtocol = RuntimeServices.resumeAnalysisService(),
        expertService: any ExpertWorkflowServiceProtocol = ExpertWorkflowService()
    ) {
        self.optimizationId = optimizationId
        self.resumeId = resumeId
        self.sections = sections
        self.atsScoreBefore = atsScoreBefore
        self.atsScoreAfter = atsScoreAfter
        self.jobTitle = jobTitle
        self.company = company
        self.contact = contact
        self.optimizationService = optimizationService
        self.analysisService = analysisService
        self.expertService = expertService
        self.didAttemptInitialSectionLoad = optimizationId == nil || !sections.isEmpty
    }

    /// Exposed for downstream tools (e.g. chat) that share the same optimization id.
    var optimizationIdentifier: String? { optimizationId }

    var isAwaitingInitialSections: Bool {
        optimizationId != nil && sections.isEmpty && !didAttemptInitialSectionLoad
    }

    var atsStatusLabel: String {
        let score = atsScoreAfter ?? atsScoreBefore ?? 0
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
            return NSLocalizedString("Useful foundation, but ATS blockers still need attention.", comment: "")
        default:
            return NSLocalizedString("Low match. Improve role keywords, title fit, metrics, and section coverage before submitting.", comment: "")
        }
    }

    var currentATSScore: Int {
        atsScoreAfter ?? atsScoreBefore ?? 0
    }

    var atsScoreDelta: Int? {
        guard let before = atsScoreBefore, let after = atsScoreAfter else { return nil }
        return after - before
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
            NSLocalizedString("Run Improve ATS for a focused keyword and metrics pass.", comment: ""),
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
        guard let token else { throw APIClientError.unauthorized }
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
        guard PDFDownloadValidator.looksLikePDF(data) else {
            let message = Self.downloadErrorMessage(from: data)
            Self.downloadLogger.error("HTTP download returned non-PDF data: \(message)")
            throw APIClientError.serverError(status: http.statusCode, message: message)
        }
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
        return stripped.isEmpty ? "Download failed" : String(stripped.prefix(240))
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

        let detail: OptimizationDetailDTO = try await RuntimeServices.sharedAPIClient.get(
            endpoint: .optimizationDetail(id: optId),
            token: token
        )
        await Self.detailCache.store(detail, for: optId)
        apply(detail: detail)
    }

    private func apply(detail: OptimizationDetailDTO) {
        sections = detail.sections
        if let detailContact = detail.contact, detailContact.hasDisplayableValue {
            contact = detailContact
        }
        if jobTitle == nil { jobTitle = detail.jobTitle }
        if company == nil  { company  = detail.company  }
        if atsScoreBefore == nil { atsScoreBefore = detail.atsScoreBefore }
        if atsScoreAfter  == nil { atsScoreAfter  = detail.atsScoreAfter  }
        atsBlockers = detail.atsBlockers
        backendDiagnosis = detail.diagnosis
        if jobURLString == nil { jobURLString = detail.jobUrl }
        if applicationId == nil { applicationId = detail.applicationId }
    }

    func applyExpertATSResult(_ applyResult: ExpertWorkflowApplyResponseDTO) {
        if let after = applyResult.newAtsScore {
            atsScoreAfter = Int((after <= 1 ? after * 100 : after).rounded())
        } else if let after = applyResult.atsImpact?.after {
            atsScoreAfter = Int((after <= 1 ? after * 100 : after).rounded())
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

    func rescanATS(token: String?) async {
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
            let response = try await analysisService.rescan(optimizationId: optId, token: token)
            if let original = response.originalScore {
                atsScoreBefore = original
            }
            if let optimized = response.optimizedScore {
                atsScoreAfter = optimized
            }
            backendDiagnosis = nil
        } catch {
            errorMessage = String(format: NSLocalizedString("Couldn't refresh the ATS score: %@", comment: ""), error.localizedDescription)
        }
    }

    func improveATS(token: String?, appState: AppState) async {
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
            let apply = try await expertService.apply(
                runId: run.runId,
                workflowType: .atsOptimizationReport,
                token: token,
                selectionIndex: nil,
                screeningSelectedIndices: nil,
                selectedFields: nil
            )
            mergeExpertApply(workflowType: .atsOptimizationReport, output: run.output, applyResult: apply)
            applyExpertATSResult(apply)
            await Self.detailCache.remove(optId)
            appState.resumeSectionsNeedRefresh = true
            appState.resumePreviewRefreshToken += 1
            await rescanATS(token: token)
            // Rescan failure (e.g. 402) is secondary — the expert improvement succeeded.
            // Clear any error rescanATS set so it doesn't mislead the user.
            errorMessage = nil
            atsUpliftMessage = "ATS improvements applied. Review the resume before submitting."
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
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
