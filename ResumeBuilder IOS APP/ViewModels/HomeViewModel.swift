import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var recentExports: [ResumeExport] = []
    var currentResumeFilename: String? = nil
    var overallScore: Int = 0
    var contentScore: Int? = nil
    var designScore: Int? = nil
    var keywordScore: Int? = nil
    var isLoading = false
    var errorMessage: String? = nil

    private let exportsService: any RecentExportsServiceProtocol
    private let historyService: any OptimizationHistoryServiceProtocol

    init(exportsService: any RecentExportsServiceProtocol = BackendConfig.useMockServices
         ? MockRecentExportsService() : RecentExportsService(),
         historyService: any OptimizationHistoryServiceProtocol = BackendConfig.useMockServices
         ? MockOptimizationHistoryService() : OptimizationHistoryService()) {
        self.exportsService = exportsService
        self.historyService = historyService
    }

    func load(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recentExports = try await exportsService.list(token: token)
            let optimizations = try await historyService.list(token: token)
            if let latest = optimizations.first {
                currentResumeFilename = latest.filename
                overallScore = latest.matchScorePercent
                contentScore = latest.contentScorePercent ?? latest.matchScorePercent
                designScore = latest.designScorePercent ?? latest.matchScorePercent
                keywordScore = latest.keywordScorePercent ?? latest.matchScorePercent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
