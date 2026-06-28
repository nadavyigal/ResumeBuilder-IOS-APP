import Foundation

enum FitCheckServiceError: Error, LocalizedError, Equatable, Sendable {
    case missingFitBlock

    var errorDescription: String? {
        switch self {
        case .missingFitBlock:
            return "The fit verdict was missing from the server response."
        }
    }
}

struct FitCheckResult: Equatable, Sendable {
    let verdict: FitVerdict
    let sessionId: String?
    let checksRemaining: Int?
}

protocol FitCheckServiceProtocol: Sendable {
    func checkFit(
        resumeURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        sessionId: String?
    ) async throws -> FitCheckResult
}

struct FitCheckService: FitCheckServiceProtocol, Sendable {
    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    func checkFit(
        resumeURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        sessionId: String?
    ) async throws -> FitCheckResult {
        let result = try await apiClient.runPublicATSCheck(
            resumeURL: resumeURL,
            jobDescription: jobDescription,
            jobDescriptionURL: jobDescriptionURL,
            sessionId: sessionId
        )
        return try Self.map(result)
    }

    static func map(_ result: ATSScoreResult) throws -> FitCheckResult {
        FitCheckResult(
            verdict: try FitVerdict.from(publicATSResult: result),
            sessionId: result.sessionId,
            checksRemaining: result.checksRemaining
        )
    }
}

struct MockFitCheckService: FitCheckServiceProtocol, Sendable {
    var result: FitCheckResult
    var error: (any Error)?

    init(
        result: FitCheckResult = FitCheckResult(
            verdict: FitVerdict(
                band: .stretch,
                score: 68,
                scoreNote: FitVerdict.defaultScoreNote,
                topGaps: [
                    ResumeGap(
                        title: "Cloud infrastructure evidence is light",
                        explanation: "The job asks for AWS and Terraform ownership; the resume mentions platform work but not those tools.",
                        severity: .high
                    ),
                    ResumeGap(
                        title: "Leadership scope needs sharper metrics",
                        explanation: "Add truthful team, scale, or business-impact numbers where they match your experience.",
                        severity: .medium
                    ),
                ],
                missingKeywords: [
                    ResumeKeyword(keyword: "Terraform", importance: .high, reason: "Listed as a must-have in the target job."),
                    ResumeKeyword(keyword: "AWS", importance: .high, reason: "Repeated in infrastructure requirements."),
                ]
            ),
            sessionId: "mock-fit-session",
            checksRemaining: 4
        ),
        error: (any Error)? = nil
    ) {
        self.result = result
        self.error = error
    }

    func checkFit(
        resumeURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        sessionId: String?
    ) async throws -> FitCheckResult {
        if let error {
            throw error
        }
        return result
    }
}
