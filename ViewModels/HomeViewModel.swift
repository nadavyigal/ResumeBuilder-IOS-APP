import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var recentExports: [ResumeExport] = []
    var currentResumeFilename: String? = nil
    var overallScore: Int = 0
    var isLoading = false
    var errorMessage: String? = nil

    private let exportsService: any RecentExportsServiceProtocol

    init(exportsService: any RecentExportsServiceProtocol = BackendConfig.useMockServices
         ? MockRecentExportsService() : RecentExportsService()) {
        self.exportsService = exportsService
    }

    func load(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recentExports = try await exportsService.list(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
