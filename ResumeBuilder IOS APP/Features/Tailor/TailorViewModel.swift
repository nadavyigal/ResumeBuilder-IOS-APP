import Foundation
import Observation

@Observable
@MainActor
final class TailorViewModel {
    var resumeId = ""
    var jobDescriptionId = ""
    var isOptimizing = false
    var reviewId: String?
    var errorMessage: String?

    private let apiClient = APIClient()

    func optimize(appState: AppState) async {
        guard !resumeId.isEmpty, !jobDescriptionId.isEmpty else {
            errorMessage = "resumeId and jobDescriptionId are required."
            return
        }

        guard appState.session != nil else {
            errorMessage = "Please sign in first."
            return
        }

        isOptimizing = true
        errorMessage = nil
        defer { isOptimizing = false }

        do {
            let payload: [String: Any] = [
                "resumeId": resumeId,
                "jobDescriptionId": jobDescriptionId,
            ]
            let response: TailorResponse = try await appState.callWithFreshToken { token in
                try await apiClient.postJSON(endpoint: .optimize, body: payload, token: token)
            }
            reviewId = response.reviewId
            if response.reviewId == nil {
                errorMessage = response.error ?? "Optimization did not return review id."
            }
        } catch APIClientError.unauthorized {
            errorMessage = "Session expired. Please sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
