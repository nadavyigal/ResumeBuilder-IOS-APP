import Foundation

// MARK: - Mock Upload

struct MockResumeUploadService: ResumeUploadServiceProtocol {
    func upload(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, token: String) async throws -> ResumeUploadResponse {
        try await Task.sleep(for: .milliseconds(800))
        return ResumeUploadResponse(
            success: true,
            resumeId: "mock-resume-001",
            jobDescriptionId: "mock-jd-001",
            reviewId: "mock-review-001",
            nextStep: "review",
            matchScore: 82,
            keyImprovements: ["Added role-specific keywords", "Strengthened summary"],
            missingKeywords: ["TypeScript", "CI/CD"],
            error: nil
        )
    }

    func publicATS(fileURL: URL, jobDescription: String?, jobDescriptionURL: String?, sessionId: String?) async throws -> ATSScoreResult {
        try await Task.sleep(for: .milliseconds(800))
        return ATSScoreResult(
            success: true,
            score: .init(overall: 74, timestamp: nil),
            preview: .init(
                topIssues: [
                    ATSIssue(category: "Keywords", severity: "medium", message: "Add more job-specific keywords.", text: nil, suggestion: nil)
                ],
                totalIssues: 3,
                lockedCount: 2
            ),
            quickWins: [
                QuickWin(title: "Add TypeScript", action: "Mention TypeScript in skills.", keyword: "TypeScript", impact: "high", reason: nil)
            ],
            checksRemaining: 4,
            sessionId: "mock-anon-session",
            error: nil
        )
    }
}

// MARK: - Mock Analysis

struct MockResumeAnalysisService: ResumeAnalysisServiceProtocol {
    func score(resumeId: String, jobDescription: String, token: String) async throws -> ResumeAnalysis {
        try await Task.sleep(for: .seconds(1))
        let sub = ATSSubScores(
            keyword_exact: 76,
            keyword_phrase: 68,
            semantic_relevance: 81,
            title_alignment: 62,
            metrics_presence: 58,
            section_completeness: 73,
            format_parseability: 84,
            recency_fit: 70
        )
        let subOrig = ATSSubScores(
            keyword_exact: 66,
            keyword_phrase: 60,
            semantic_relevance: 70,
            title_alignment: 55,
            metrics_presence: 50,
            section_completeness: 68,
            format_parseability: 79,
            recency_fit: 65
        )
        let suggestions: [ATSAuthSuggestion] = [
            ATSAuthSuggestion(
                id: "suggest-1",
                text: "Surface TypeScript & CI/CD in your skills cluster near the top of the resume.",
                category: "keywords",
                quickWin: true,
                estimatedGain: 8
            ),
            ATSAuthSuggestion(
                id: "suggest-2",
                text: "Flatten multi-column bullets so ATS parsers read experience in order.",
                category: "formatting",
                quickWin: false,
                estimatedGain: 6
            ),
            ATSAuthSuggestion(
                id: "suggest-3",
                text: "Rewrite your summary headline to mirror the posting title verbatim.",
                category: "content",
                quickWin: true,
                estimatedGain: 5
            ),
        ]
        let qw: [ATSAuthQuickWinSuggestion] = [
            .init(id: "qw-1", originalText: "Built web apps.", optimizedText: "Built React + TypeScript web apps with measurable latency wins.", estimatedImpact: 12, rationale: "Adds missing stack keywords.", improvementType: nil),
            .init(id: "qw-2", originalText: "Managed deployments.", optimizedText: "Owned CI/CD pipelines cutting release cadence by 40%.", estimatedImpact: 9, rationale: "Quantifies DevOps relevance.", improvementType: nil),
        ]
        return ResumeAnalysis(
            overall: 74,
            ats: 82,
            content: 72,
            design: 78,
            missingKeywords: ["TypeScript", "CI/CD", "Kubernetes"],
            subscores: sub,
            subscoresOriginal: subOrig,
            suggestions: suggestions,
            authQuickWins: qw
        )
    }

    func rescan(optimizationId: String, token: String) async throws -> ATSRescanResponse {
        try await Task.sleep(for: .milliseconds(600))
        return ATSRescanResponse(success: true, optimizedScore: 86, originalScore: 71)
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
    func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
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
    private static let allTemplates: [DesignTemplate] = [
        // traditional
        DesignTemplate(id: "trad-1", slug: "classic-ats",     name: "Classic ATS",      description: "Clean, ATS-friendly layout",           category: "traditional", isPremium: false, thumbnailURL: nil, atsScore: 98),
        DesignTemplate(id: "trad-2", slug: "timeless",        name: "Timeless",          description: "Conservative serif layout",             category: "traditional", isPremium: false, thumbnailURL: nil, atsScore: 95),
        // modern
        DesignTemplate(id: "mod-1",  slug: "modern-pro",      name: "Modern Pro",        description: "Contemporary single-column design",     category: "modern",      isPremium: false, thumbnailURL: nil, atsScore: 90),
        DesignTemplate(id: "mod-2",  slug: "sleek",           name: "Sleek",             description: "Minimalist accent-line style",          category: "modern",      isPremium: false, thumbnailURL: nil, atsScore: 88),
        // creative
        DesignTemplate(id: "cre-1",  slug: "creative-edge",   name: "Creative Edge",     description: "Stand-out visual design",               category: "creative",    isPremium: true,  thumbnailURL: nil, atsScore: 72),
        DesignTemplate(id: "cre-2",  slug: "portfolio",       name: "Portfolio",         description: "Sidebar layout for visual roles",       category: "creative",    isPremium: true,  thumbnailURL: nil, atsScore: 68),
        // corporate
        DesignTemplate(id: "corp-1", slug: "executive",       name: "Executive",         description: "Premium executive template",            category: "corporate",   isPremium: true,  thumbnailURL: nil, atsScore: 92),
        DesignTemplate(id: "corp-2", slug: "boardroom",       name: "Boardroom",         description: "Formal two-column corporate layout",    category: "corporate",   isPremium: true,  thumbnailURL: nil, atsScore: 89),
    ]

    func templates(category: String, token: String) async throws -> [DesignTemplate] {
        try await Task.sleep(for: .milliseconds(600))
        let filtered = Self.allTemplates.filter { $0.category == category }
        return filtered.isEmpty ? Self.allTemplates.filter { $0.category == "traditional" } : filtered
    }

    func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
        try await Task.sleep(for: .milliseconds(800))
        let category = Self.allTemplates.first { $0.id == request.templateId }?.category ?? "traditional"
        let html = MockResumeHTMLBuilder.build(accentHex: request.customization.accentColor, category: category)
        return RenderPreviewResponse(success: true, previewHTML: html, error: nil)
    }

    func applyCustomization(optimizationId: String, templateId: String, customization: DesignCustomization, token: String) async throws -> Bool {
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

// MARK: - Mock HTML builder

enum MockResumeHTMLBuilder {
    static func build(accentHex: String = "6366F1", category: String = "traditional") -> String {
        switch category.lowercased() {
        case "modern":      return buildModern(accentHex: accentHex)
        case "creative":    return buildCreative(accentHex: accentHex)
        case "corporate":   return buildCorporate(accentHex: accentHex)
        default:            return buildTraditional(accentHex: accentHex)
        }
    }

    // MARK: Traditional — centered header, horizontal rule sections

    private static func buildTraditional(accentHex: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: Georgia, serif; font-size: 10pt; color: #1a1a1a; background: #fff; padding: 32px 40px; line-height: 1.45; }
          .hdr { text-align: center; margin-bottom: 10px; }
          .name { font-size: 18pt; font-weight: bold; color: #1a1a1a; }
          .contact { font-size: 8.5pt; color: #555; margin-top: 4px; }
          .rule { border: none; border-top: 1.5px solid #\(accentHex); margin: 10px 0 8px; }
          h2 { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1.2px; color: #\(accentHex); margin-bottom: 6px; }
          p { margin-bottom: 4px; font-size: 9.5pt; }
          .entry { margin-bottom: 8px; }
          .row { display: flex; justify-content: space-between; }
          .bold { font-weight: bold; }
          .meta { font-size: 8.5pt; color: #555; }
          .date { font-size: 8.5pt; color: #777; }
          ul { margin-left: 15px; margin-top: 2px; }
          li { font-size: 9pt; margin-bottom: 2px; }
        </style>
        </head><body>
          <div class="hdr">
            <div class="name">Alex Johnson</div>
            <div class="contact">alex.johnson@email.com · (555) 123-4567 · San Francisco, CA</div>
          </div>
          <hr class="rule">
          <h2>Summary</h2>
          <p>Experienced software engineer with 8+ years building scalable distributed systems. Expert in TypeScript, Go, and cloud-native architecture.</p>
          <hr class="rule">
          <h2>Experience</h2>
          <div class="entry">
            <div class="row"><span class="bold">Senior Software Engineer — Stripe</span><span class="date">2021 – Present</span></div>
            <ul>
              <li>Architected fraud detection pipeline processing 2M events/day, reducing chargebacks 28%</li>
              <li>Led monolith-to-microservices migration, cutting deploy time from 45 min to 8 min</li>
            </ul>
          </div>
          <hr class="rule">
          <h2>Skills</h2>
          <p>TypeScript · Go · React · PostgreSQL · Redis · Kubernetes · AWS · CI/CD</p>
          <hr class="rule">
          <h2>Education</h2>
          <p class="bold">B.S. Computer Science — UC Berkeley, 2019</p>
        </body></html>
        """
    }

    // MARK: Modern — left accent sidebar, left-aligned name

    private static func buildModern(accentHex: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 10pt; color: #1a1a1a; background: #fff; line-height: 1.45; display: flex; min-height: 100vh; }
          .sidebar { width: 4px; background: linear-gradient(to bottom, #\(accentHex), #\(accentHex)88); flex-shrink: 0; }
          .main { padding: 28px 36px; flex: 1; }
          .name { font-size: 16pt; font-weight: bold; color: #1a1a1a; }
          .contact { font-size: 8.5pt; color: #555; margin-top: 3px; }
          .rule { border: none; border-top: 0.5px solid #ddd; margin: 10px 0 8px; }
          h2 { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; color: #\(accentHex); margin-bottom: 5px; }
          p { margin-bottom: 4px; font-size: 9.5pt; }
          .entry { margin-bottom: 7px; }
          .row { display: flex; justify-content: space-between; }
          .bold { font-weight: 600; }
          .meta { font-size: 8.5pt; color: #555; }
          .date { font-size: 8.5pt; color: #888; }
          ul { margin-left: 14px; margin-top: 2px; }
          li { font-size: 9pt; margin-bottom: 2px; }
        </style>
        </head><body>
          <div class="sidebar"></div>
          <div class="main">
            <div class="name">Alex Johnson</div>
            <div class="contact">alex.johnson@email.com · (555) 123-4567 · San Francisco, CA</div>
            <hr class="rule">
            <h2>Summary</h2>
            <p>Software engineer with 8+ years in scalable distributed systems. TypeScript, Go, cloud-native architecture.</p>
            <hr class="rule">
            <h2>Experience</h2>
            <div class="entry">
              <div class="row"><span class="bold">Senior Software Engineer</span><span class="date">2021 – Present</span></div>
              <div class="meta">Stripe · San Francisco</div>
              <ul>
                <li>Fraud detection pipeline: 2M events/day, −28% chargebacks</li>
                <li>Microservices migration: deploy time 45 min → 8 min</li>
              </ul>
            </div>
            <hr class="rule">
            <h2>Skills</h2>
            <p>TypeScript · Go · React · PostgreSQL · Redis · Kubernetes · AWS</p>
            <hr class="rule">
            <h2>Education</h2>
            <p class="bold">B.S. Computer Science — UC Berkeley, 2019</p>
          </div>
        </body></html>
        """
    }

    // MARK: Creative — bold gradient header, coloured section labels

    private static func buildCreative(accentHex: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 10pt; color: #1a1a1a; background: #fff; line-height: 1.45; }
          .hdr { background: linear-gradient(135deg, #\(accentHex), #\(accentHex)99); padding: 24px 32px; }
          .name { font-size: 18pt; font-weight: bold; color: #fff; }
          .contact { font-size: 8.5pt; color: rgba(255,255,255,0.8); margin-top: 4px; }
          .body { padding: 20px 32px; }
          .section-label { font-size: 9pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; color: #\(accentHex); margin: 12px 0 4px; }
          p { margin-bottom: 4px; font-size: 9.5pt; }
          .entry { margin-bottom: 8px; }
          .row { display: flex; justify-content: space-between; }
          .bold { font-weight: 600; }
          .meta { font-size: 8.5pt; color: #555; }
          .date { font-size: 8.5pt; color: #888; }
          ul { margin-left: 14px; margin-top: 2px; }
          li { font-size: 9pt; margin-bottom: 2px; }
        </style>
        </head><body>
          <div class="hdr">
            <div class="name">Alex Johnson</div>
            <div class="contact">alex.johnson@email.com · (555) 123-4567 · San Francisco, CA</div>
          </div>
          <div class="body">
            <div class="section-label">Summary</div>
            <p>Software engineer with 8+ years in scalable distributed systems. TypeScript, Go, cloud-native architecture.</p>
            <div class="section-label">Experience</div>
            <div class="entry">
              <div class="row"><span class="bold">Senior Software Engineer — Stripe</span><span class="date">2021–Present</span></div>
              <ul>
                <li>Fraud pipeline: 2M events/day, −28% chargebacks</li>
                <li>Microservices migration: deploy 45 min → 8 min</li>
              </ul>
            </div>
            <div class="section-label">Skills</div>
            <p>TypeScript · Go · React · PostgreSQL · Redis · Kubernetes · AWS</p>
            <div class="section-label">Education</div>
            <p class="bold">B.S. Computer Science — UC Berkeley, 2019</p>
          </div>
        </body></html>
        """
    }

    // MARK: Corporate — two-column body (sidebar left, experience right)

    private static func buildCorporate(accentHex: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: Georgia, serif; font-size: 10pt; color: #1a1a1a; background: #fff; padding: 28px 36px; line-height: 1.45; }
          .top { display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 2px solid #\(accentHex); padding-bottom: 8px; margin-bottom: 12px; }
          .name { font-size: 16pt; font-weight: bold; color: #1a1a1a; }
          .contact { font-size: 8pt; color: #555; text-align: right; }
          .cols { display: flex; gap: 16px; }
          .left { width: 30%; border-right: 0.5px solid #ddd; padding-right: 12px; }
          .right { flex: 1; }
          h2 { font-size: 8.5pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; color: #\(accentHex); margin: 0 0 5px; }
          .section { margin-bottom: 12px; }
          p { margin-bottom: 3px; font-size: 9pt; }
          .entry { margin-bottom: 7px; }
          .row { display: flex; justify-content: space-between; }
          .bold { font-weight: bold; }
          .date { font-size: 8pt; color: #888; }
          ul { margin-left: 13px; margin-top: 2px; }
          li { font-size: 8.5pt; margin-bottom: 2px; }
        </style>
        </head><body>
          <div class="top">
            <div class="name">Alex Johnson</div>
            <div class="contact">alex.johnson@email.com<br>(555) 123-4567 · San Francisco</div>
          </div>
          <div class="cols">
            <div class="left">
              <div class="section">
                <h2>Skills</h2>
                <p>TypeScript · Go</p>
                <p>React · Node.js</p>
                <p>PostgreSQL · Redis</p>
                <p>Kubernetes · AWS</p>
              </div>
              <div class="section">
                <h2>Education</h2>
                <p class="bold">B.S. Computer Science</p>
                <p>UC Berkeley, 2019</p>
              </div>
            </div>
            <div class="right">
              <div class="section">
                <h2>Summary</h2>
                <p>Software engineer with 8+ years building scalable distributed systems. TypeScript, Go, cloud-native architecture.</p>
              </div>
              <div class="section">
                <h2>Experience</h2>
                <div class="entry">
                  <div class="row"><span class="bold">Senior Software Engineer — Stripe</span><span class="date">2021–Present</span></div>
                  <ul>
                    <li>Fraud pipeline: 2M events/day, −28% chargebacks</li>
                    <li>Microservices: deploy 45 min → 8 min</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </body></html>
        """
    }
}
