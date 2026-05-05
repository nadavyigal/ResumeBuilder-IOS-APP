import Foundation

enum Endpoint {
    // Existing
    case publicATSCheck
    case convertAnonymousSession
    case atsScore
    case optimize
    case applications
    case credits
    case uploadResume
    case iapVerify

    // New – v1 surface
    case refineSection
    case refineSectionApply
    case designTemplates(category: String)
    case designRenderPreview
    case designCustomize(optimizationId: String)
    case optimizations
    case optimizationsExport
    case download(id: String)

    var path: String {
        switch self {
        case .publicATSCheck:                  return "/api/public/ats-check"
        case .convertAnonymousSession:         return "/api/public/convert-session"
        case .atsScore:                        return "/api/ats/score"
        case .optimize:                        return "/api/optimize"
        case .applications:                    return "/api/v1/applications"
        case .credits:                         return "/api/v1/credits"
        case .uploadResume:                    return "/api/upload-resume"
        case .iapVerify:                       return "/api/v1/iap/verify"
        case .refineSection:                   return "/api/v1/refine-section"
        case .refineSectionApply:              return "/api/v1/refine-section/apply"
        case .designTemplates:                 return "/api/v1/design/templates"
        case .designRenderPreview:             return "/api/v1/design/render-preview"
        case .designCustomize(let id):         return "/api/v1/design/\(id)/customize"
        case .optimizations:                   return "/api/optimizations"
        case .optimizationsExport:             return "/api/optimizations/export"
        case .download(let id):                return "/api/download/\(id)"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .designTemplates(let category):
            return [URLQueryItem(name: "category", value: category)]
        default:
            return []
        }
    }
}
