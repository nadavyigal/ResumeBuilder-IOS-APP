import Foundation
import Observation

@Observable
@MainActor
final class ApplicationDetailViewModel {
    private(set) var item: ApplicationItem
    private(set) var expertReportsCount: Int = 0
    var isLoading = false
    var actionError: String?
    var isMarkingApplied = false
    var isAttaching = false

    private let service = ApplicationTrackingService()

    init(application: ApplicationItem) {
        self.item = application
    }

    func refresh(token: String?) async {
        guard let token else {
            actionError = "Please sign in first."
            return
        }

        isLoading = true
        actionError = nil
        defer { isLoading = false }

        do {
            let detail = try await service.fetchDetail(id: item.id, token: token)
            item = detail.application
        } catch {
            actionError = error.localizedDescription
        }

        do {
            let reports = try await service.fetchExpertReports(applicationId: item.id, token: token)
            expertReportsCount = reports.count
        } catch {
            expertReportsCount = 0
        }
    }

    func clearActionError() {
        actionError = nil
    }

    func markApplied(token: String?) async {
        guard let token else {
            actionError = "Please sign in first."
            return
        }
        isMarkingApplied = true
        actionError = nil
        defer { isMarkingApplied = false }

        do {
            try await service.markApplied(id: item.id, token: token)
            await refresh(token: token)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func attachOptimizedResume(optimizationHistoryId: String, token: String?) async {
        guard let token else {
            actionError = "Please sign in first."
            return
        }
        isAttaching = true
        actionError = nil
        defer { isAttaching = false }

        do {
            try await service.attachOptimized(
                applicationId: item.id,
                optimizedResumeId: optimizationHistoryId,
                token: token
            )
            await refresh(token: token)
        } catch {
            actionError = error.localizedDescription
        }
    }
}
