import Foundation

enum RuntimeServices {
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
