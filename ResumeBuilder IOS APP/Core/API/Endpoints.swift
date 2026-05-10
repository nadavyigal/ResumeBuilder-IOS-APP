import Foundation

enum Endpoint {
    // Existing
    case publicATSCheck
    case convertAnonymousSession
    case atsScore
    case atsRescan
    case optimize
    case applications
    case applicationDetail(id: String)
    case applicationMarkApplied(id: String)
    case applicationAttachOptimized(id: String)
    case applicationExpertReports(id: String)
    case credits
    case uploadResume
    case iapVerify
    case resumeText(id: String)

    // New – v1 surface
    case refineSection
    case refineSectionApply
    case designTemplates(category: String)
    case designRenderPreview
    case designCustomize(optimizationId: String)
    case optimizations
    case optimizationsBulk
    case optimizationsExport
    case download(id: String)

    /// Chat (`/api/v1/chat`)
    case chatSend
    /// Active sessions only (matches web `?status=active` when resuming chat).
    case chatSessionsActive
    case chatSession(id: String)
    case chatMessages(sessionId: String)
    case chatApproveChange
    case chatSessionApply(sessionId: String)

    /// Expert workflows (`/api/v1/expert-workflows`).
    case expertWorkflowRunPost
    case expertWorkflowRunGet(id: String)
    case expertWorkflowApply(runId: String)

    /// Phase 6 — optimization review
    case optimizationReview(id: String)
    case optimizationReviewApply(id: String)

    /// Phase 6 — modification history / revert
    case modificationHistory(optimizationId: String)
    case modificationRevert(id: String)

    /// Phase 6 — style history / revert
    case stylesHistory(optimizationId: String)
    case stylesRevert

    /// Design assignment undo (complements `styles/revert` when history rows are missing).
    case designUndo(optimizationId: String)

    /// Fetch optimization sections + job context for a given optimization ID.
    case optimizationDetail(id: String)

    var path: String {
        switch self {
        case .publicATSCheck:                  return "/api/public/ats-check"
        case .convertAnonymousSession:         return "/api/public/convert-session"
        case .atsScore:                        return "/api/ats/score"
        case .atsRescan:                       return "/api/ats/rescan"
        case .optimize:                        return "/api/optimize"
        case .applications:                    return "/api/v1/applications"
        case .applicationDetail(let id):        return "/api/v1/applications/\(id)"
        case .applicationMarkApplied(let id): return "/api/v1/applications/\(id)/mark-applied"
        case .applicationAttachOptimized(let id): return "/api/v1/applications/\(id)/attach-optimized"
        case .applicationExpertReports(let id): return "/api/v1/applications/\(id)/expert-reports"
        case .credits:                         return "/api/v1/credits"
        case .uploadResume:                    return "/api/upload-resume"
        case .iapVerify:                       return "/api/v1/iap/verify"
        case .resumeText(let id):              return "/api/resumes/\(id)"
        case .refineSection:                   return "/api/v1/refine-section"
        case .refineSectionApply:              return "/api/v1/refine-section/apply"
        case .designTemplates:                 return "/api/v1/design/templates"
        case .designRenderPreview:             return "/api/v1/design/render-preview"
        case .designCustomize(let id):         return "/api/v1/design/\(id)/customize"
        case .optimizations:                   return "/api/optimizations"
        case .optimizationsBulk:               return "/api/optimizations/bulk"
        case .optimizationsExport:             return "/api/optimizations/export"
        case .download(let id):                return "/api/download/\(id)"
        case .chatSend:                        return "/api/v1/chat"
        case .chatSessionsActive:           return "/api/v1/chat/sessions"
        case .chatSession(let id):             return "/api/v1/chat/sessions/\(id)"
        case .chatMessages(let sessionId):     return "/api/v1/chat/sessions/\(sessionId)/messages"
        case .chatApproveChange:              return "/api/v1/chat/approve-change"
        case .chatSessionApply(let sessionId): return "/api/v1/chat/sessions/\(sessionId)/apply"
        case .expertWorkflowRunPost:
            return "/api/v1/expert-workflows/run"
        case .expertWorkflowRunGet(let id):
            return "/api/v1/expert-workflows/runs/\(id)"
        case .expertWorkflowApply(let runId):
            return "/api/v1/expert-workflows/runs/\(runId)/apply"

        /// Phase 6 — optimization review (grouped changes before apply)
        case .optimizationReview(let id):
            return "/api/v1/optimization-reviews/\(id)"
        case .optimizationReviewApply(let id):
            return "/api/v1/optimization-reviews/\(id)/apply"

        /// Phase 6 — content modification audit / revert
        case .modificationHistory:
            return "/api/v1/modifications/history"
        case .modificationRevert(let id):
            return "/api/v1/modifications/\(id)/revert"

        /// Phase 6 — style customization history / revert
        case .stylesHistory:
            return "/api/v1/styles/history"
        case .stylesRevert:
            return "/api/v1/styles/revert"

        /// Fallback single-step undo when style history is sparse (design assignment stack).
        case .designUndo(let optimizationId):
            return "/api/v1/design/\(optimizationId)/undo"

        case .optimizationDetail(let id):
            return "/api/v1/optimizations/\(id)"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .designTemplates(let category):
            return [URLQueryItem(name: "category", value: category)]
        case .chatSessionsActive:
            return [URLQueryItem(name: "status", value: "active")]
        case .modificationHistory(let optimizationId):
            return [URLQueryItem(name: "optimization_id", value: optimizationId)]
        case .stylesHistory(let optimizationId):
            return [URLQueryItem(name: "optimization_id", value: optimizationId)]
        default:
            return []
        }
    }
}
