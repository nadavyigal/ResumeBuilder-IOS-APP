import Foundation
import Observation

@Observable
@MainActor
final class DesignViewModel {
    var templates: [DesignTemplate] = []
    var selectedTemplateId: String? = nil
    var customization = DesignCustomization.default
    var activeCategory = "ats_safe"
    var isLoading = false
    var isApplying = false
    var errorMessage: String? = nil

    private let optimizationId: String?
    private let designService: any ResumeDesignServiceProtocol

    init(
        optimizationId: String?,
        designService: any ResumeDesignServiceProtocol = BackendConfig.useMockServices
            ? MockResumeDesignService() : ResumeDesignService()
    ) {
        self.optimizationId = optimizationId
        self.designService = designService
    }

    var selectedTemplate: DesignTemplate? {
        templates.first { $0.id == selectedTemplateId }
    }

    func loadTemplates(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await designService.templates(category: activeCategory, token: token)
            if selectedTemplateId == nil { selectedTemplateId = templates.first?.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyDesign(token: String?) async -> Bool {
        guard let token, let optId = optimizationId else { return false }
        isApplying = true
        defer { isApplying = false }
        do {
            return try await designService.applyCustomization(optimizationId: optId, customization: customization, token: token)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
