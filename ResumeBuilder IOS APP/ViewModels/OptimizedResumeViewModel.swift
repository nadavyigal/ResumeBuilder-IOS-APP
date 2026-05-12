import Foundation
import Observation

@Observable
@MainActor
final class OptimizedResumeViewModel {
    var sections: [OptimizedResumeSection]
    /// Source resume uploaded for optimize (passed through for parity with Chat metadata).
    var resumeId: String?
    var isRefining = false
    var isSaving = false
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

    private let optimizationId: String?
    private let optimizationService: any ResumeOptimizationServiceProtocol

    init(
        optimizationId: String?,
        resumeId: String? = nil,
        sections: [OptimizedResumeSection] = [],
        atsScoreBefore: Int? = nil,
        atsScoreAfter: Int? = nil,
        jobTitle: String? = nil,
        company: String? = nil,
        optimizationService: any ResumeOptimizationServiceProtocol = BackendConfig.useMockServices
            ? MockResumeOptimizationService() : ResumeOptimizationService()
    ) {
        self.optimizationId = optimizationId
        self.resumeId = resumeId
        self.sections = sections
        self.atsScoreBefore = atsScoreBefore
        self.atsScoreAfter = atsScoreAfter
        self.jobTitle = jobTitle
        self.company = company
        self.optimizationService = optimizationService
    }

    /// Exposed for downstream tools (e.g. chat) that share the same optimization id.
    var optimizationIdentifier: String? { optimizationId }

    /// Plain text of all sections joined for clipboard copy.
    var plainTextResume: String {
        sections.map { "\($0.type.displayName.uppercased())\n\($0.body)" }
            .joined(separator: "\n\n")
    }

    /// Downloads the PDF for this optimization and returns a temp file URL for sharing.
    func downloadPDF(appState: AppState) async throws -> URL {
        try await appState.callWithFreshToken { token in
            try await self.downloadPDF(with: token)
        }
    }

    func downloadPDF(token: String?) async throws -> URL {
        guard let optId = optimizationId else { throw APIClientError.invalidResponse }
        guard let token else { throw APIClientError.unauthorized }
        return try await downloadPDF(with: token, optimizationId: optId)
    }

    private func downloadPDF(with token: String) async throws -> URL {
        guard let optId = optimizationId else { throw APIClientError.invalidResponse }
        return try await downloadPDF(with: token, optimizationId: optId)
    }

    private func downloadPDF(with token: String, optimizationId optId: String) async throws -> URL {
        var components = URLComponents(url: BackendConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/download/\(optId)"
        components.queryItems = [URLQueryItem(name: "fmt", value: "pdf")]
        guard let url = components.url else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        if http.statusCode == 401 { throw APIClientError.unauthorized }
        if http.statusCode == 402 { throw APIClientError.paymentRequired }
        guard (200...299).contains(http.statusCode) else { throw APIClientError.invalidResponse }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("Resume_\(optId).pdf")
        try data.write(to: dest, options: .atomic)
        return dest
    }

    /// Fetches sections + job context from the backend when sections are empty (e.g. navigated
    /// from OptimizationReviewView where the apply response contains only the optimizationId).
    func loadSections(appState: AppState) async {
        guard sections.isEmpty, !isLoadingSections else { return }
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.loadSections(with: token)
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
                try await self.loadSections(with: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSections(token: String?) async {
        guard sections.isEmpty, !isLoadingSections, let optId = optimizationId, let token else { return }
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            try await loadSections(with: token, optimizationId: optId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSections(with token: String) async throws {
        guard let optId = optimizationId else { return }
        try await loadSections(with: token, optimizationId: optId)
    }

    private func loadSections(with token: String, optimizationId optId: String) async throws {
        let detail: OptimizationDetailDTO = try await APIClient().get(
            endpoint: .optimizationDetail(id: optId),
            token: token
        )
        sections = detail.sections
        if jobTitle == nil { jobTitle = detail.jobTitle }
        if company == nil  { company  = detail.company  }
        if atsScoreBefore == nil { atsScoreBefore = detail.atsScoreBefore }
        if atsScoreAfter  == nil { atsScoreAfter  = detail.atsScoreAfter  }
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
                errorMessage = response.error ?? "Refine failed"
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
        defer { isSaving = false }
        do {
            let request = RefineSectionApplyRequest(sectionId: sectionId, optimizationId: optId, acceptedText: acceptedText)
            let success = try await optimizationService.applySectionRefine(request, token: token)
            if success, let idx = sections.firstIndex(where: { $0.id == sectionId }) {
                sections[idx].body = acceptedText
                sections[idx].status = "improved"
            }
            pendingRefine = nil
            activeSectionId = nil
        } catch let apiError as APIClientError {
            switch apiError {
            case .serverError(let status, _) where status >= 500:
                errorMessage = "The server encountered an issue saving this change (\(status)). Please try again later."
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRefine() {
        pendingRefine = nil
        activeSectionId = nil
    }

    /// Mirrors optimistic updates after `/api/v1/expert-workflows/runs/:id/apply`, which does not return `rewrite_data`.
    func mergeExpertApply(
        workflowType: ExpertWorkflowType,
        output: JSONValue,
        applyResult: ExpertWorkflowApplyResponseDTO
    ) {
        guard applyResult.success != false else { return }

        switch workflowType {
        case .fullResumeRewrite:
            guard applyResult.updatedFields.contains("entire_resume") else { return }
            guard case .object(let root) = output, let rewritten = root["rewritten_resume"] else { return }
            if let rebuilt = ExpertResumeSectionMapping.sections(fromRewrittenResume: rewritten) {
                sections = rebuilt
            }
        case .achievementQuantifier:
            guard applyResult.updatedFields.contains(where: { $0.contains("experience") }) else { return }
            ExpertResumeSectionMapping.patchQuantifierBullets(into: &sections, output: output)
        case .professionalSummaryLab:
            guard applyResult.updatedFields.contains("summary") else { return }
            ExpertResumeSectionMapping.patchSummaryLab(into: &sections, output: output)
        case .atsOptimizationReport:
            guard applyResult.updatedFields.contains(where: { $0.lowercased().contains("skills") }) else {
                return
            }
            ExpertResumeSectionMapping.patchSkillsFromAtsReport(into: &sections, output: output)
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
