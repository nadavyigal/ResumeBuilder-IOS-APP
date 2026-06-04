import Foundation
import Observation

@MainActor
protocol SubmitResumePDFProviding: AnyObject {
    var optimizationIdentifier: String? { get }
    var jobTitle: String? { get }
    var company: String? { get }
    var contact: ResumeContact? { get }
    var jobURLString: String? { get }

    func downloadPDF(token: String?) async throws -> URL
}

extension OptimizedResumeViewModel: SubmitResumePDFProviding {}

struct SubmitApplicationPackage: Identifiable, Sendable {
    let id = UUID()
    let application: ApplicationItem
    let resumePDFURL: URL
    let coverLetterText: String
    let screeningAnswers: [ExpertScreeningAnswer]
    let jobURL: URL?
    let coverLetterRunId: String
}

@Observable
@MainActor
final class SubmitApplicationViewModel {
    var jobTitle: String
    var companyName: String
    var sourceURLString = ""
    var coverLetterContext = ""
    var isSubmitting = false
    var errorMessage: String?
    var package: SubmitApplicationPackage?

    private weak var resumeProvider: (any SubmitResumePDFProviding)?
    private let applicationService: any ApplicationTrackingServiceProtocol
    private let expertService: any ExpertWorkflowServiceProtocol

    init(
        resumeProvider: any SubmitResumePDFProviding,
        applicationService: any ApplicationTrackingServiceProtocol = ApplicationTrackingService(),
        expertService: any ExpertWorkflowServiceProtocol = ExpertWorkflowService()
    ) {
        self.resumeProvider = resumeProvider
        self.applicationService = applicationService
        self.expertService = expertService
        self.jobTitle = resumeProvider.jobTitle ?? ""
        self.companyName = resumeProvider.company ?? ""
        self.sourceURLString = resumeProvider.jobURLString ?? ""
    }

    var canSubmit: Bool {
        resumeProvider?.optimizationIdentifier != nil
            && !jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    func clearError() {
        errorMessage = nil
    }

    func submit(token: String?) async {
        guard let token else {
            errorMessage = "Please sign in first."
            return
        }
        guard let resumeProvider, let optimizationId = resumeProvider.optimizationIdentifier else {
            errorMessage = "Optimization is not ready yet."
            return
        }

        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJobTitle.isEmpty, !trimmedCompany.isEmpty else {
            errorMessage = "Add the role and company before creating the package."
            return
        }

        isSubmitting = true
        errorMessage = nil
        package = nil
        defer { isSubmitting = false }

        do {
            let resumeURL = try await resumeProvider.downloadPDF(token: token)
            let application = try await applicationService.createApplication(
                ApplicationCreateRequest(
                    jobTitle: trimmedJobTitle,
                    companyName: trimmedCompany,
                    sourceURL: normalizedSourceURLString,
                    status: "saved",
                    optimizationId: optimizationId,
                    optimizedResumeId: optimizationId,
                    contact: contactJSON(from: resumeProvider.contact)
                ),
                token: token
            )
            try await applicationService.attachOptimized(
                applicationId: application.id,
                optimizedResumeId: optimizationId,
                token: token
            )
            try await applicationService.markApplied(id: application.id, token: token)

            // Run cover letter and screening answers in parallel.
            async let coverLetterRunTask = expertService.run(
                type: .coverLetterArchitect,
                optimizationId: optimizationId,
                token: token,
                evidenceInputs: coverLetterEvidence
            )
            async let screeningRunTask = expertService.run(
                type: .screeningAnswerStudio,
                optimizationId: optimizationId,
                token: token,
                evidenceInputs: [:]
            )

            let coverLetterRun = try await coverLetterRunTask
            let screeningRun = try? await screeningRunTask

            let parsed = ExpertReportParsing.parsedOutput(from: coverLetterRun.output)
            let selectedIndex = clampedCoverLetterIndex(parsed.recommendedIndex, count: parsed.coverLetterVariants.count)
            let coverLetter = selectedIndex.flatMap { parsed.coverLetterVariants[safe: $0]?.letter }
                ?? firstString(in: coverLetterRun.output, keys: ["letter", "body", "cover_letter", "text", "content", "full_letter"])
                ?? ""
            guard !coverLetter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SubmitApplicationError.emptyCoverLetter
            }

            _ = try await expertService.apply(
                runId: coverLetterRun.runId,
                workflowType: .coverLetterArchitect,
                token: token,
                selectionIndex: selectedIndex ?? 0,
                screeningSelectedIndices: nil,
                selectedFields: nil
            )
            _ = try await applicationService.saveExpertReport(
                applicationId: application.id,
                runId: coverLetterRun.runId,
                token: token
            )

            // Extract and save screening answers only after successful persistence.
            var screeningAnswers: [ExpertScreeningAnswer] = []
            if let screeningRun {
                let generatedAnswers = ExpertReportParsing.parsedOutput(from: screeningRun.output).screeningAnswers
                if !generatedAnswers.isEmpty {
                    // Use the original backend indices (ExpertScreeningAnswer.id = enumerated idx),
                    // not the filtered-list positions, so the server selects the correct rows.
                    let selectedIndices = generatedAnswers.map(\.id)
                    do {
                        _ = try await expertService.apply(
                            runId: screeningRun.runId,
                            workflowType: .screeningAnswerStudio,
                            token: token,
                            selectionIndex: nil,
                            screeningSelectedIndices: selectedIndices,
                            selectedFields: nil
                        )
                        _ = try await applicationService.saveExpertReport(
                            applicationId: application.id,
                            runId: screeningRun.runId,
                            token: token
                        )
                        screeningAnswers = generatedAnswers
                    } catch {
                        // Screening failure is non-fatal; package ships with cover letter only.
                        screeningAnswers = []
                    }
                }
            }

            package = SubmitApplicationPackage(
                application: application,
                resumePDFURL: resumeURL,
                coverLetterText: coverLetter,
                screeningAnswers: screeningAnswers,
                jobURL: normalizedSourceURL,
                coverLetterRunId: coverLetterRun.runId
            )
        } catch let error as SubmitApplicationError {
            errorMessage = error.localizedDescription
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedSourceURLString: String? {
        let trimmed = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedSourceURL: URL? {
        guard let raw = normalizedSourceURLString else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }

    private var coverLetterEvidence: [String: JSONValue] {
        let trimmed = coverLetterContext.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [:] : ["user_context": .string(trimmed)]
    }

    private func clampedCoverLetterIndex(_ index: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let raw = index ?? 0
        return min(max(raw, 0), count - 1)
    }

    private func contactJSON(from contact: ResumeContact?) -> JSONValue? {
        guard let contact, contact.hasDisplayableValue else { return nil }
        var object: [String: JSONValue] = [:]
        if let name = contact.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            object["name"] = .string(name)
        }
        if let title = contact.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            object["title"] = .string(title)
        }
        if let email = contact.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            object["email"] = .string(email)
        }
        if let phone = contact.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            object["phone"] = .string(phone)
        }
        if let location = contact.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            object["location"] = .string(location)
        }
        if let linkedin = contact.linkedin?.trimmingCharacters(in: .whitespacesAndNewlines), !linkedin.isEmpty {
            object["linkedin"] = .string(linkedin)
        }
        if let portfolio = contact.portfolio?.trimmingCharacters(in: .whitespacesAndNewlines), !portfolio.isEmpty {
            object["portfolio"] = .string(portfolio)
        }
        return object.isEmpty ? nil : .object(object)
    }

    private func firstString(in value: JSONValue, keys: [String]) -> String? {
        guard case .object(let object) = value else { return nil }
        for key in keys {
            if let string = object[key]?.stringValue {
                return string
            }
        }
        for child in object.values {
            if let found = firstString(in: child, keys: keys) {
                return found
            }
        }
        return nil
    }
}

enum SubmitApplicationError: LocalizedError, Sendable {
    case emptyCoverLetter

    var errorDescription: String? {
        switch self {
        case .emptyCoverLetter:
            return "The cover letter response was empty. Please try again."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
