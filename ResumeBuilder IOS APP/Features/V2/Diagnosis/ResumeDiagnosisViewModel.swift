import Foundation
import Observation

@Observable
@MainActor
final class ResumeDiagnosisViewModel {
    var optimizationId: String?
    var diagnosis: ResumeDiagnosis?
    var isLoading = false
    var errorMessage: String?
    var hasLoaded = false

    private let apiClient: APIClient

    init(
        optimizationId: String?,
        diagnosis: ResumeDiagnosis? = nil,
        apiClient: APIClient = RuntimeServices.sharedAPIClient
    ) {
        self.optimizationId = optimizationId
        self.diagnosis = diagnosis
        self.apiClient = apiClient
        self.hasLoaded = diagnosis != nil
    }

    var isEmpty: Bool {
        optimizationId?.isEmpty != false && diagnosis == nil
    }

    func load(appState: AppState) async {
        guard diagnosis == nil else {
            hasLoaded = true
            return
        }
        guard let optimizationId, !optimizationId.isEmpty else {
            hasLoaded = true
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        let client = apiClient
        do {
            let detail: OptimizationDetailDTO = try await appState.callWithFreshToken { token in
                try await client.get(endpoint: .optimizationDetail(id: optimizationId), token: token)
            }
            diagnosis = ResumeDiagnosisMapper.make(from: detail)
        } catch let apiError as APIClientError {
            errorMessage = apiError.userFacingMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
