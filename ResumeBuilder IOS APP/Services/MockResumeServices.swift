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
        let html = MockResumeHTMLBuilder.build(accentHex: request.customization.accentColor)
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
    static func build(accentHex: String = "6366F1") -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: Georgia, 'Times New Roman', serif; font-size: 10pt; color: #1a1a1a; background: #fff; padding: 36px 44px; line-height: 1.45; }
          .name { font-size: 20pt; font-weight: bold; letter-spacing: 0.5px; color: #\(accentHex); }
          .contact { font-size: 9pt; color: #555; margin-top: 4px; }
          .divider { border: none; border-top: 1.5px solid #\(accentHex); margin: 14px 0 10px; }
          h2 { font-size: 9.5pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1.2px; color: #\(accentHex); margin-bottom: 7px; }
          p { margin-bottom: 5px; }
          .entry { margin-bottom: 10px; }
          .entry-header { display: flex; justify-content: space-between; }
          .entry-title { font-weight: bold; font-size: 10pt; }
          .entry-meta { font-size: 9pt; color: #555; margin-bottom: 3px; }
          .entry-date { font-size: 9pt; color: #777; }
          ul { margin-left: 17px; margin-top: 3px; }
          li { margin-bottom: 3px; font-size: 9.5pt; }
          .skills-grid { display: flex; flex-wrap: wrap; gap: 4px 14px; }
          .skill { font-size: 9.5pt; }
        </style>
        </head>
        <body>
          <div class="name">Alex Johnson</div>
          <div class="contact">alex.johnson@email.com &nbsp;·&nbsp; (555) 123-4567 &nbsp;·&nbsp; linkedin.com/in/alexjohnson &nbsp;·&nbsp; San Francisco, CA</div>
          <hr class="divider">

          <h2>Summary</h2>
          <p>Experienced software engineer with 8+ years building scalable distributed systems at high-growth companies. Track record of reducing infrastructure costs by 35%, leading cross-functional teams of 10+, and delivering customer-facing features that drive measurable retention. Expert in TypeScript, Go, and cloud-native architecture.</p>
          <hr class="divider">

          <h2>Experience</h2>
          <div class="entry">
            <div class="entry-header">
              <span class="entry-title">Senior Software Engineer</span>
              <span class="entry-date">Jun 2021 – Present</span>
            </div>
            <div class="entry-meta">Stripe · San Francisco, CA</div>
            <ul>
              <li>Architected real-time fraud detection pipeline processing 2M events/day, reducing chargebacks by 28%</li>
              <li>Led migration of 40-service monolith to microservices, cutting deployment time from 45 min to 8 min</li>
              <li>Mentored 5 junior engineers; 3 promoted to mid-level within 18 months</li>
            </ul>
          </div>
          <div class="entry">
            <div class="entry-header">
              <span class="entry-title">Software Engineer II</span>
              <span class="entry-date">Mar 2019 – May 2021</span>
            </div>
            <div class="entry-meta">Shopify · Remote</div>
            <ul>
              <li>Built checkout optimization feature A/B tested across 6M merchants, increasing conversion by 4.2%</li>
              <li>Reduced API P99 latency by 60% via Redis caching layer and query optimizations</li>
              <li>On-call lead for Payments platform serving $50B+ in annual GMV</li>
            </ul>
          </div>
          <hr class="divider">

          <h2>Skills</h2>
          <div class="skills-grid">
            <span class="skill">TypeScript</span><span class="skill">Go</span><span class="skill">Python</span>
            <span class="skill">React</span><span class="skill">Node.js</span><span class="skill">PostgreSQL</span>
            <span class="skill">Redis</span><span class="skill">Kafka</span><span class="skill">Kubernetes</span>
            <span class="skill">AWS</span><span class="skill">CI/CD</span><span class="skill">System Design</span>
          </div>
          <hr class="divider">

          <h2>Education</h2>
          <div class="entry">
            <div class="entry-header">
              <span class="entry-title">B.S. Computer Science</span>
              <span class="entry-date">2015 – 2019</span>
            </div>
            <div class="entry-meta">University of California, Berkeley</div>
          </div>
        </body>
        </html>
        """
    }
}
