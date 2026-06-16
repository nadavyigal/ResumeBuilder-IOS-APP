import SwiftUI

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

    var headline: LocalizedStringKey {
        switch self {
        case .noResume: return "Upload your resume for a recruiter-style read"
        case .resumeNoJob: return "Paste a job to reveal missing keywords"
        case .readyForFreeATS: return "Ready for a free ATS check"
        case .readyToOptimize: return "Ready for your resume diagnosis"
        case .atsComplete: return "Your free ATS score is in"
        case .optimizing: return "Finding the aha moments…"
        case .optimizedReady: return "Your optimized resume is ready"
        case .exportComplete: return "Resume exported successfully"
        }
    }

    var subheadline: LocalizedStringKey {
        switch self {
        case .noResume:
            return "See what a recruiter may notice in 7 seconds, then get the next fix."
        case .resumeNoJob:
            return "A job description lets us compare keywords, gaps, and role fit."
        case .readyForFreeATS:
            return "See the first score before signing in, then unlock the full diagnosis."
        case .readyToOptimize:
            return "Get your match score, top gaps, missing signals, and a better first rewrite."
        case .atsComplete:
            return "Sign in to unlock full optimization and PDF export."
        case .optimizing:
            return "Reading your resume, comparing it to the job, and preparing recruiter-style feedback."
        case .optimizedReady:
            return "Review the diagnosis, preview the PDF, or refine further."
        case .exportComplete:
            return "Share it, apply, or keep improving in Optimized."
        }
    }
}
