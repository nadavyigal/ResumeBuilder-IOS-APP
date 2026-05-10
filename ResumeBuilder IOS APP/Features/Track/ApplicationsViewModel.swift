import Foundation
import Observation

@Observable
@MainActor
final class ApplicationsViewModel {
    var applications: [ApplicationItem] = []
    var isLoading = false
    var errorMessage: String?

    private let service = ApplicationTrackingService()

    func load(token: String?) async {
        guard let token else {
            errorMessage = "Please sign in first."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            applications = try await service.listApplications(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func application(withId id: String) -> ApplicationItem? {
        applications.first { $0.id == id }
    }
}
