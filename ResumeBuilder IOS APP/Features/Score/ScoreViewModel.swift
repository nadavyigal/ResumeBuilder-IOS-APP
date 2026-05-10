import Foundation
import Observation

@Observable
@MainActor
final class ScoreViewModel {
    var jobDescription = ""
    var isLoading = false
    var result: ATSScoreResult?
    var errorMessage: String?

    private let apiClient = APIClient()

    func runScore(appState: AppState) async {
        guard !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Job description is required."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if appState.session != nil {
                let payload: [String: Any] = [
                    "resume_original": jobDescription,
                    "resume_optimized": jobDescription,
                    "job_description": jobDescription,
                ]
                result = try await appState.callWithFreshToken { token in
                    try await apiClient.postJSON(endpoint: .atsScore, body: payload, token: token)
                }
            } else {
                errorMessage = "Public scoring requires resume upload flow from onboarding."
            }
        } catch APIClientError.unauthorized {
            errorMessage = "Session expired. Please sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
