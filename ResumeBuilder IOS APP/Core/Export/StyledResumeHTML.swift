import Foundation

/// The backend-rendered design HTML for an optimization, built the same way for the
/// on-screen preview and for PDF export so an export always matches what the
/// preview would show.
enum StyledResumeHTML {
    static let defaultTemplateId = "ats-clean"

    static func request(
        optimizationId: String,
        templateId: String?,
        customization: DesignCustomization?
    ) -> RenderPreviewRequest {
        RenderPreviewRequest(
            optimizationId: optimizationId,
            templateId: templateId ?? defaultTemplateId,
            customization: customization ?? .default,
            resumeData: nil,
            locale: LocalizationManager.shared.language.rawValue
        )
    }

    /// Forces RTL for Hebrew résumés even if the backend ignored the locale hint.
    /// Direction comes from the résumé content, so an English résumé is never forced
    /// RTL. When sections are empty, tags are stripped first so Latin tag and
    /// attribute names don't skew the detection.
    static func applyingDirection(
        to html: String,
        sections: [OptimizedResumeSection],
        contact: ResumeContact?
    ) -> String {
        let plainText = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let rtl = ResumeTextDirection.isRTL(sections: sections, contact: contact)
            || (sections.isEmpty && ResumeTextDirection.isRTLText(plainText))
        return ResumeHTMLDirection.applyRTLIfNeeded(to: html, isRTL: rtl)
    }

    /// Nil when the backend returns no HTML.
    static func fetch(
        optimizationId: String,
        templateId: String?,
        customization: DesignCustomization?,
        sections: [OptimizedResumeSection],
        contact: ResumeContact?,
        token: String,
        service: any ResumeDesignServiceProtocol
    ) async throws -> String? {
        let response = try await service.renderPreview(
            request(optimizationId: optimizationId, templateId: templateId, customization: customization),
            token: token
        )
        guard let html = response.previewHTML, !html.isEmpty else { return nil }
        return applyingDirection(to: html, sections: sections, contact: contact)
    }
}
