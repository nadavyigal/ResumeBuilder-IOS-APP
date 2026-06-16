import Foundation
import Observation
import OSLog

@MainActor
protocol SubmitResumePDFProviding: AnyObject {
    var optimizationIdentifier: String? { get }
    var jobTitle: String? { get }
    var company: String? { get }
    var contact: ResumeContact? { get }
    var jobURLString: String? { get }

    func refreshSubmitPackageContext(token: String?) async
    func downloadPDF(token: String?) async throws -> URL
}

extension OptimizedResumeViewModel: SubmitResumePDFProviding {}

struct SubmitApplicationPackage: Identifiable, Sendable {
    let id = UUID()
    var application: ApplicationItem?
    let optimizationId: String
    let jobTitle: String
    let companyName: String
    let sourceURLString: String?
    let resumePDFURL: URL
    let coverLetterText: String
    let screeningAnswers: [ExpertScreeningAnswer]
    let jobURL: URL?
    let coverLetterRunId: String
    let coverLetterSelectionIndex: Int
    let screeningRunId: String?
}

@Observable
@MainActor
final class SubmitApplicationViewModel {
    var jobTitle: String
    var companyName: String
    var sourceURLString = ""
    var coverLetterContext = ""
    var isSubmitting = false
    var isSavingPackage = false
    var errorMessage: String?
    var package: SubmitApplicationPackage?

    private weak var resumeProvider: (any SubmitResumePDFProviding)?
    private let applicationService: any ApplicationTrackingServiceProtocol
    private let expertService: any ExpertWorkflowServiceProtocol
    private static let logger = Logger(subsystem: "ResumeBuilder", category: "SubmitPackage")

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
            && !isSubmitting
    }

    var missingContextMessage: String? {
        let missingRole = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let missingCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch (missingRole, missingCompany) {
        case (true, true):
            return "Role and company were not detected. You can edit them, or the package will use safe placeholders."
        case (true, false):
            return "Role was not detected. You can edit it, or the package will use Target Role."
        case (false, true):
            return "Company was not detected. You can edit it, or the package will use Company not specified."
        case (false, false):
            return nil
        }
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

        await resumeProvider.refreshSubmitPackageContext(token: token)
        applyProviderContextIfNeeded()

        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let packageJobTitle = trimmedJobTitle.isEmpty ? "Target Role" : trimmedJobTitle
        let packageCompany = trimmedCompany.isEmpty ? "Company not specified" : trimmedCompany

        isSubmitting = true
        errorMessage = nil
        package = nil
        defer { isSubmitting = false }

        do {
            Self.logger.info("Submit package start optimizationId=\(optimizationId)")
            let resumeURL = try await resumeProvider.downloadPDF(token: token)
            Self.logger.info("Submit package PDF ready")

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
            Self.logger.info("Submit package expert workflows completed coverLetterRunId=\(coverLetterRun.runId)")

            let parsed = ExpertReportParsing.parsedOutput(from: coverLetterRun.output)
            let selectedIndex = clampedCoverLetterIndex(parsed.recommendedIndex, count: parsed.coverLetterVariants.count)
            let coverLetter = selectedIndex.flatMap { parsed.coverLetterVariants[safe: $0]?.letter }
                ?? firstString(in: coverLetterRun.output, keys: ["letter", "body", "cover_letter", "text", "content", "full_letter"])
                ?? ""
            guard !coverLetter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SubmitApplicationError.emptyCoverLetter
            }

            // Extract screening answers for the package preview. Persistence happens only
            // after the user confirms saving the package to Me.
            var screeningAnswers: [ExpertScreeningAnswer] = []
            var screeningRunId: String?
            if let screeningRun {
                let generatedAnswers = ExpertReportParsing.parsedOutput(from: screeningRun.output).screeningAnswers
                if !generatedAnswers.isEmpty {
                    screeningAnswers = generatedAnswers
                    screeningRunId = screeningRun.runId
                }
            }

            package = SubmitApplicationPackage(
                application: nil,
                optimizationId: optimizationId,
                jobTitle: packageJobTitle,
                companyName: packageCompany,
                sourceURLString: normalizedSourceURLString,
                resumePDFURL: resumeURL,
                coverLetterText: coverLetter,
                screeningAnswers: screeningAnswers,
                jobURL: normalizedSourceURL,
                coverLetterRunId: coverLetterRun.runId,
                coverLetterSelectionIndex: selectedIndex ?? 0,
                screeningRunId: screeningRunId
            )
            Self.logger.info("Submit package ready")
        } catch let error as SubmitApplicationError {
            errorMessage = error.localizedDescription
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePackageToMe(token: String?) async {
        guard let token else {
            errorMessage = "Please sign in first."
            return
        }
        guard var package else {
            errorMessage = "Create the package before saving it to Me."
            return
        }
        guard package.application == nil else { return }

        isSavingPackage = true
        errorMessage = nil
        defer { isSavingPackage = false }

        do {
            let application = try await applicationService.createApplication(
                ApplicationCreateRequest(
                    jobTitle: package.jobTitle,
                    companyName: package.companyName,
                    sourceURL: package.sourceURLString,
                    status: "saved",
                    optimizationId: package.optimizationId,
                    optimizedResumeId: package.optimizationId,
                    contact: contactJSON(from: resumeProvider?.contact)
                ),
                token: token
            )
            Self.logger.info("Submit package application created id=\(application.id)")
            try await applicationService.attachOptimized(
                applicationId: application.id,
                optimizedResumeId: package.optimizationId,
                token: token
            )

            _ = try await expertService.apply(
                runId: package.coverLetterRunId,
                workflowType: .coverLetterArchitect,
                token: token,
                selectionIndex: package.coverLetterSelectionIndex,
                screeningSelectedIndices: nil,
                selectedFields: nil
            )
            _ = try await applicationService.saveExpertReport(
                applicationId: application.id,
                runId: package.coverLetterRunId,
                token: token
            )
            Self.logger.info("Submit package cover letter saved")

            if let screeningRunId = package.screeningRunId, !package.screeningAnswers.isEmpty {
                do {
                    _ = try await expertService.apply(
                        runId: screeningRunId,
                        workflowType: .screeningAnswerStudio,
                        token: token,
                        selectionIndex: nil,
                        screeningSelectedIndices: package.screeningAnswers.map(\.id),
                        selectedFields: nil
                    )
                    _ = try await applicationService.saveExpertReport(
                        applicationId: application.id,
                        runId: screeningRunId,
                        token: token
                    )
                } catch {
                    // Screening persistence is useful, but the package is still valid with
                    // the optimized resume, job link, and cover letter.
                }
            }

            package.application = packageApplication(from: application, package: package)
            self.package = package
            Self.logger.info("Submit package saved to Me")
            AnalyticsService.shared.track(.submitPackageSaved(hasCoverLetter: !package.coverLetterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyProviderContextIfNeeded() {
        guard let resumeProvider else { return }
        if jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let providerJobTitle = resumeProvider.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providerJobTitle.isEmpty {
            jobTitle = providerJobTitle
        }
        if companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let providerCompany = resumeProvider.company?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providerCompany.isEmpty {
            companyName = providerCompany
        }
        if sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let providerURL = resumeProvider.jobURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providerURL.isEmpty {
            sourceURLString = providerURL
        }
    }

    private func packageApplication(from application: ApplicationItem, package: SubmitApplicationPackage) -> ApplicationItem {
        ApplicationItem(
            id: application.id,
            jobTitle: application.jobTitle ?? package.jobTitle,
            companyName: application.companyName ?? package.companyName,
            appliedDate: application.appliedDate,
            status: application.status ?? "saved",
            applyClickedAt: application.applyClickedAt,
            atsScore: application.atsScore,
            optimizationId: application.optimizationId ?? package.optimizationId,
            optimizedResumeURL: application.optimizedResumeURL,
            optimizedResumeId: application.optimizedResumeId ?? package.optimizationId,
            sourceURL: application.sourceURL ?? package.sourceURLString,
            jobExtraction: application.jobExtraction,
            contact: application.contact
        )
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
