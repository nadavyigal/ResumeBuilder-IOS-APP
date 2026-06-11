import Foundation

enum RuntimeFeatures {
    /// `/api/v1/resumes` is not available on the production backend yet.
    /// Keep runtime live-only, but do not expose a broken saved-resume flow.
    /// TODO(Stage2-RES-RESUMES): remove flag when `/api/v1/resumes` ships.
    static let isResumeLibraryEnabled = false
}

enum RuntimeServices {
    static let sharedAPIClient = APIClient()

    static func resumeUploadService() -> any ResumeUploadServiceProtocol {
        ResumeUploadService()
    }

    static func resumeAnalysisService() -> any ResumeAnalysisServiceProtocol {
        ResumeAnalysisService()
    }

    static func resumeOptimizationService() -> any ResumeOptimizationServiceProtocol {
        ResumeOptimizationService()
    }

    static func resumeExportService() -> any ResumeExportServiceProtocol {
        ResumeExportService()
    }

    static func recentExportsService() -> any RecentExportsServiceProtocol {
        RecentExportsService()
    }

    static func optimizationHistoryService() -> any OptimizationHistoryServiceProtocol {
        OptimizationHistoryService()
    }

    static func resumeLibraryService() -> any ResumeLibraryServiceProtocol {
        ResumeLibraryService()
    }

    static func resumeDesignService() -> any ResumeDesignServiceProtocol {
        ResumeDesignService()
    }
}
