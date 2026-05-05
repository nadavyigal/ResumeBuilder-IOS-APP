import Foundation

// MARK: - Mock Upload

struct MockResumeUploadService: ResumeUploadServiceProtocol {
    func upload(fileURL: URL, token: String) async throws -> ResumeUploadResponse {
        try await Task.sleep(for: .milliseconds(800))
        return ResumeUploadResponse(success: true, resumeId: "mock-resume-001", error: nil)
    }
}

// MARK: - Mock Analysis

struct MockResumeAnalysisService: ResumeAnalysisServiceProtocol {
    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        try await Task.sleep(for: .seconds(1))
        return ResumeAnalysis(overall: 74, ats: 82, content: 68, design: 71, missingKeywords: ["TypeScript", "CI/CD", "Kubernetes"])
    }

    func improvements(resumeId: String, jobDescription: String, token: String) async throws -> [ResumeImprovement] {
        try await Task.sleep(for: .milliseconds(500))
        return [
            ResumeImprovement(id: "1", title: "Add missing keywords", description: "Include TypeScript, CI/CD, Kubernetes from the job posting", impact: "high"),
            ResumeImprovement(id: "2", title: "Quantify achievements", description: "Add metrics to bullet points (e.g., reduced latency by 40%)", impact: "high"),
            ResumeImprovement(id: "3", title: "Strengthen summary", description: "Lead with your most relevant experience for this role", impact: "medium"),
            ResumeImprovement(id: "4", title: "Update skills section", description: "Move modern stack items to the top", impact: "low"),
        ]
    }
}

// MARK: - Mock Optimization

struct MockResumeOptimizationService: ResumeOptimizationServiceProtocol {
    func optimize(resumeId: String, jobDescription: String, token: String) async throws -> OptimizeResponse {
        try await Task.sleep(for: .seconds(2))
        return OptimizeResponse(
            success: true,
            sections: [
                OptimizedResumeSection(id: "s1", type: .summary, body: "Results-driven software engineer with 5+ years building scalable distributed systems. Expert in React, TypeScript, and CI/CD pipelines.", status: "optimized", aiNote: "Added TypeScript and CI/CD keywords"),
                OptimizedResumeSection(id: "s2", type: .experience, body: "Senior Engineer @ TechCorp — Led migration of monolith to microservices, reducing p99 latency by 40% and cutting infrastructure costs by $200K/yr.", status: "improved", aiNote: "Added quantified metrics"),
                OptimizedResumeSection(id: "s3", type: .skills, body: "TypeScript, React, Node.js, Kubernetes, Docker, CI/CD, PostgreSQL, Redis, AWS", status: "optimized", aiNote: "Reordered by relevance to job"),
            ],
            optimizationId: "mock-opt-001",
            error: nil
        )
    }

    func refineSection(_ request: RefineSectionRequest, token: String) async throws -> RefineSectionResponse {
        try await Task.sleep(for: .seconds(1))
        return RefineSectionResponse(
            success: true,
            original: "Original section text goes here.",
            suggested: "Refined section text with \(request.instruction) applied. More impactful and keyword-rich.",
            error: nil
        )
    }

    func applySectionRefine(_ request: RefineSectionApplyRequest, token: String) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(300))
        return true
    }
}

// MARK: - Mock Design

struct MockResumeDesignService: ResumeDesignServiceProtocol {
    func templates(category: String, token: String) async throws -> [DesignTemplate] {
        try await Task.sleep(for: .milliseconds(600))
        return [
            DesignTemplate(id: "t1", slug: "classic-ats", name: "Classic ATS", description: "Clean, ATS-friendly layout", category: "ats_safe", isPremium: false, thumbnailURL: nil, atsScore: 98),
            DesignTemplate(id: "t2", slug: "modern-pro", name: "Modern Pro", description: "Contemporary single-column design", category: "modern", isPremium: false, thumbnailURL: nil, atsScore: 90),
            DesignTemplate(id: "t3", slug: "creative-edge", name: "Creative Edge", description: "Stand-out visual design", category: "creative", isPremium: true, thumbnailURL: nil, atsScore: 72),
            DesignTemplate(id: "t4", slug: "executive", name: "Executive", description: "Premium executive template", category: category, isPremium: true, thumbnailURL: nil, atsScore: 88),
        ]
    }

    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        try await Task.sleep(for: .milliseconds(800))
        return RenderPreviewResponse(success: true, previewHTML: "<html><body><p>Resume preview</p></body></html>", error: nil)
    }

    func applyCustomization(optimizationId: String, customization: DesignCustomization, token: String) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(500))
        return true
    }
}

// MARK: - Mock Export

struct MockResumeExportService: ResumeExportServiceProtocol {
    func exportPDF(optimizationId: String, token: String) async throws -> ExportResponse {
        try await Task.sleep(for: .seconds(1))
        return ExportResponse(success: true, exportId: "mock-export-001", downloadURL: nil, error: nil)
    }

    func downloadPDF(id: String, token: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(500))
        return Data("%PDF-1.4 mock pdf data".utf8)
    }
}

// MARK: - Mock Recent Exports

struct MockRecentExportsService: RecentExportsServiceProtocol {
    func list(token: String) async throws -> [ResumeExport] {
        try await Task.sleep(for: .milliseconds(400))
        return [
            ResumeExport(id: "e1", filename: "Resume_SWE_Google.pdf", kind: .optimized, createdAt: "2026-04-30T10:00:00Z", fileURL: nil),
            ResumeExport(id: "e2", filename: "Resume_PM_Stripe.pdf", kind: .designed, createdAt: "2026-04-28T14:30:00Z", fileURL: nil),
        ]
    }
}
