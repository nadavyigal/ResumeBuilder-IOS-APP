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
    private var didLoadInitialAssignment = false

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
        customization = .default
        didApplyCustomization = false
        styleHistory = []
        didLoadInitialAssignment = false
    }

    func loadTemplates(token: String?) async {
        guard let token else { return }
        if !didLoadInitialAssignment, let optId = optimizationId {
            didLoadInitialAssignment = true
            await loadCurrentAssignment(optimizationId: optId, token: token, shouldSyncCategory: true)
        }
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

    func loadCurrentAssignment(token: String?) async {
        guard let token, let optId = optimizationId else { return }
        await loadCurrentAssignment(optimizationId: optId, token: token, shouldSyncCategory: true)
        didLoadInitialAssignment = true
    }

    func selectCategory(_ category: String) {
        guard activeCategory != category else { return }
        activeCategory = category
        if let cached = templatesByCategory[category] {
            templates = cached
            selectedTemplateId = cached.first?.id
        } else {
            templates = []
            selectedTemplateId = nil
        }
    }

    func selectTemplate(_ templateId: String) {
        selectedTemplateId = templateId
    }

    private func loadCurrentAssignment(optimizationId optId: String, token: String, shouldSyncCategory: Bool) async {
        do {
            guard let assignment = try await designService.currentAssignment(optimizationId: optId, token: token) else { return }
            if let template = assignment.template {
                templatesByCategory[template.category] = mergeTemplate(template, into: templatesByCategory[template.category] ?? [])
                if shouldSyncCategory, activeCategory != template.category {
                    activeCategory = template.category
                }
                if activeCategory == template.category {
                    templates = mergeTemplate(template, into: templates)
                }
                selectedTemplateId = template.id
            }
            if let customizationValue = assignment.customization,
               let decoded = Self.designCustomization(from: customizationValue) {
                customization = decoded
            }
            didApplyCustomization = true
        } catch let apiError as APIClientError {
            if case .serverError(let status, _) = apiError, status == 404 {
                return
            }
        } catch {
            // Non-fatal: the user can still choose a fresh template.
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
                await loadCurrentAssignment(optimizationId: optId, token: token, shouldSyncCategory: true)
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
            await loadCurrentAssignment(optimizationId: optId, token: token, shouldSyncCategory: true)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func mergeTemplate(_ template: DesignTemplate, into existing: [DesignTemplate]) -> [DesignTemplate] {
        var merged = existing.filter { $0.id != template.id }
        merged.insert(template, at: 0)
        return merged
    }

    private static func designCustomization(from value: JSONValue) -> DesignCustomization? {
        guard case .object(let root) = value else { return nil }
        let accent =
            root["accent_color"]?.stringValue
            ?? root["accentColor"]?.stringValue
            ?? root["color_scheme"]?["accent"]?.stringValue
            ?? root["color_scheme"]?["primary"]?.stringValue
        let fontStyle =
            root["font_style"]?.stringValue
            ?? root["fontStyle"]?.stringValue
            ?? fontStyle(from: root["font_family"])
        let spacing =
            root["spacing"]?.numberValue
            ?? spacingValue(from: root["spacing"])

        return DesignCustomization(
            spacing: min(1, max(0, spacing ?? DesignCustomization.default.spacing)),
            accentColor: (accent ?? DesignCustomization.default.accentColor).replacingOccurrences(of: "#", with: ""),
            fontStyle: fontStyle ?? DesignCustomization.default.fontStyle
        )
    }

    private static func fontStyle(from value: JSONValue?) -> String? {
        guard case .object(let fonts) = value else { return nil }
        let merged = [
            fonts["heading"]?.stringValue,
            fonts["body"]?.stringValue,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        if merged.contains("georgia") { return "classic" }
        if merged.contains("system") { return "minimal" }
        if merged.isEmpty { return nil }
        return "modern"
    }

    private static func spacingValue(from value: JSONValue?) -> Double? {
        guard case .object(let spacing) = value else { return nil }
        let lineHeightString = spacing["line_height"]?.stringValue ?? spacing["lineHeight"]?.stringValue
        let lineHeight = lineHeightString.flatMap(Double.init)
        if let lineHeight {
            if lineHeight <= 1.4 { return 0.2 }
            if lineHeight >= 1.6 { return 0.8 }
            return 0.5
        }
        let gap = spacing["section_gap"]?.stringValue ?? ""
        if gap.contains("10") { return 0.2 }
        if gap.contains("22") { return 0.8 }
        return nil
    }

    private func userFacingMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            return apiError.userFacingMessage
        }
        return error.localizedDescription
    }
}
