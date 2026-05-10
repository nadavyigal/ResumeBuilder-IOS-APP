import Foundation
import Observation

struct DownloadedPDF: Identifiable {
    let id = UUID()
    let url: URL
}

@Observable
@MainActor
final class HistoryViewModel {
    var optimizations: [OptimizationHistoryItem] = []
    var searchText = ""
    var isLoading = false
    var downloadingId: String?
    var errorMessage: String?
    var downloadedPDF: DownloadedPDF?

    private let historyService: any OptimizationHistoryServiceProtocol

    init(historyService: any OptimizationHistoryServiceProtocol = BackendConfig.useMockServices
         ? MockOptimizationHistoryService() : OptimizationHistoryService()) {
        self.historyService = historyService
    }

    var filteredOptimizations: [OptimizationHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return optimizations }

        return optimizations.filter { item in
            item.filename.localizedCaseInsensitiveContains(query)
                || (item.company?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.jobTitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func load(token: String?) async {
        guard let token else {
            optimizations = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            optimizations = try await historyService.list(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFilteredItems(at offsets: IndexSet, token: String?) async {
        guard let token else {
            errorMessage = "Sign in to delete optimization history."
            return
        }

        let ids = offsets.map { filteredOptimizations[$0].id }
        guard !ids.isEmpty else { return }

        do {
            let response = try await historyService.delete(ids: ids, token: token)
            if response.success {
                optimizations.removeAll { ids.contains($0.id) }
            } else {
                errorMessage = response.errors?.first?.error ?? "Delete failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadPDF(for item: OptimizationHistoryItem, token: String?) async {
        guard let token else {
            errorMessage = "Sign in to download PDFs."
            return
        }

        downloadingId = item.id
        errorMessage = nil
        defer { downloadingId = nil }

        do {
            let url = try await PDFExporter.downloadPDF(optimizationId: item.id, token: token)
            downloadedPDF = DownloadedPDF(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
