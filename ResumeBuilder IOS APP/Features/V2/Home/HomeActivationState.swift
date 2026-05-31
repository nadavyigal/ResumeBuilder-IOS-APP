import Foundation

/// Guest-first activation states derived from existing Tailor/AppState inputs.
enum HomeActivationState: Equatable, Sendable {
    case noResume
    case resumeNoJob
    case readyForFreeATS
    case readyToOptimize
    case atsComplete
    case optimizing
    case optimizedReady
    case exportComplete

    struct Inputs: Equatable, Sendable {
        var hasResume: Bool
        var hasJob: Bool
        var isAuthenticated: Bool
        var isOptimizing: Bool
        var hasATSResult: Bool
        var hasOptimizationId: Bool
        var isExportComplete: Bool
    }

    static func derive(from inputs: Inputs) -> HomeActivationState {
        if inputs.isOptimizing { return .optimizing }
        if inputs.isExportComplete, inputs.hasOptimizationId { return .exportComplete }
        if inputs.hasOptimizationId { return .optimizedReady }
        if inputs.hasATSResult, !inputs.isAuthenticated { return .atsComplete }
        if inputs.hasResume, inputs.hasJob {
            return inputs.isAuthenticated ? .readyToOptimize : .readyForFreeATS
        }
        if inputs.hasResume { return .resumeNoJob }
        return .noResume
    }

    var headline: String {
        switch self {
        case .noResume: return "Upload your resume"
        case .resumeNoJob: return "Add the job you're targeting"
        case .readyForFreeATS: return "Ready for a free ATS check"
        case .readyToOptimize: return "Ready to optimize"
        case .atsComplete: return "Your free ATS score is in"
        case .optimizing: return "Working on your resume…"
        case .optimizedReady: return "Your optimized resume is ready"
        case .exportComplete: return "Resume exported successfully"
        }
    }

    var subheadline: String {
        switch self {
        case .noResume:
            return "Start with a text-based PDF — we'll tailor it to your next role."
        case .resumeNoJob:
            return "Paste a job link or description so we can match keywords."
        case .readyForFreeATS:
            return "See how your resume scores before you sign in."
        case .readyToOptimize:
            return "AI will rewrite your resume for this specific job."
        case .atsComplete:
            return "Sign in to unlock full optimization and PDF export."
        case .optimizing:
            return "This usually takes under a minute."
        case .optimizedReady:
            return "Preview and export your PDF, or refine further."
        case .exportComplete:
            return "Share it, apply, or keep improving in Optimized."
        }
    }
}
