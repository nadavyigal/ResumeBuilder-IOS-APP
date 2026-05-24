import Foundation
import Observation

@Observable
@MainActor
final class DesignViewModel {
    var templates: [DesignTemplate] = []
    var selectedTemplateId: String? = nil
    var customization = DesignCustomization.default
    var activeCategory = "traditional"
    var isLoading = false
    var isApplying = false
    var isUndoing = false
    var errorMessage: String? = nil

    /// Style customization audit rows (`GET /api/v1/styles/history`).
    var styleHistory: [StyleHistoryEntryDTO] = []
    /// True after a successful `Apply Design` this session (enables `design/undo` fallback).
    private(set) var didApplyCustomization = false

    private(set) var optimizationId: String?
    private let designService: any ResumeDesignServiceProtocol
    private let apiClient = APIClient()
    private var templatesByCategory: [String: [DesignTemplate]] = [:]
    private var loadingCategories: Set<String> = []

    init(
        optimizationId: String?,
        designService: any ResumeDesignServiceProtocol = RuntimeServices.resumeDesignService()
    ) {
        self.optimizationId = optimizationId
        self.designService = designService
    }

    var selectedTemplate: DesignTemplate? {
        templates.first { $0.id == selectedTemplateId }
    }

    /// Undo last design step: prefers `styles/revert` when history has a prior customization, otherwise `design/undo`.
    var canUndoDesign: Bool {
        guard optimizationId != nil else { return false }
        return styleHistory.count >= 2 || didApplyCustomization
    }

    /// Called when a new optimization completes — resets template state so the next design load uses the fresh ID.
    func setOptimizationId(_ id: String) {
        optimizationId = id
        templates = []
        selectedTemplateId = nil
        didApplyCustomization = false
        styleHistory = []
    }

    func loadTemplates(token: String?) async {
        guard let token else { return }
        let category = activeCategory
        if let cached = templatesByCategory[category] {
            templates = cached
            if selectedTemplateId == nil || selectedTemplate?.category != category {
                selectedTemplateId = cached.first?.id
            }
            return
        }
        guard !loadingCategories.contains(category) else { return }
        loadingCategories.insert(category)
        isLoading = true
        defer {
            loadingCategories.remove(category)
            if activeCategory == category {
                isLoading = false
            }
        }
        do {
            let loadedTemplates = try await designService.templates(category: category, token: token)
            templatesByCategory[category] = loadedTemplates
            guard activeCategory == category else { return }
            templates = loadedTemplates
            if selectedTemplateId == nil || selectedTemplate?.category != category {
                selectedTemplateId = loadedTemplates.first?.id
            }
        } catch {
            if activeCategory == category {
                errorMessage = userFacingMessage(for: error)
            }
        }
    }

    func loadStyleHistory(token: String?) async {
        guard let token, let optId = optimizationId else { return }
        do {
            let env: StyleHistoryEnvelope = try await apiClient.getWithQuery(
                endpoint: .stylesHistory(optimizationId: optId),
                token: token
            )
            styleHistory = env.history
        } catch {
            // Non-fatal: table may be empty or endpoint unavailable in some environments.
            styleHistory = []
        }
    }

    func applyDesign(token: String?) async -> Bool {
        guard let token, let optId = optimizationId else { return false }
        guard !isLoading else {
            errorMessage = "Design templates are still loading. Try again in a moment."
            return false
        }
        guard let templateId = selectedTemplateId else {
            errorMessage = "Choose a design template first."
            return false
        }
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }
        do {
            let ok = try await designService.applyCustomization(
                optimizationId: optId,
                templateId: templateId,
                customization: customization,
                token: token
            )
            if ok {
                didApplyCustomization = true
                styleHistory = []
            }
            return ok
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    func undoLastDesign(token: String?) async {
        guard let token, let optId = optimizationId else { return }
        isUndoing = true
        errorMessage = nil
        defer { isUndoing = false }
        do {
            if styleHistory.count >= 2, let prevId = styleHistory[1].customizationId {
                let body: [String: Any] = [
                    "optimization_id": optId,
                    "customization_id": prevId,
                ]
                let res: StyleRevertResponseDTO = try await apiClient.postJSON(
                    endpoint: .stylesRevert,
                    body: body,
                    token: token
                )
                if res.success == false, res.error != nil {
                    throw APIClientError.serverError(status: 400, message: res.error ?? "Revert failed")
                }
            } else {
                let res: DesignUndoResponseDTO = try await apiClient.postJSON(
                    endpoint: .designUndo(optimizationId: optId),
                    body: [:],
                    token: token
                )
                if let err = res.error, !err.isEmpty {
                    throw APIClientError.serverError(status: 400, message: err)
                }
            }
            styleHistory = []
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            return apiError.userFacingMessage
        }
        return error.localizedDescription
    }
}
