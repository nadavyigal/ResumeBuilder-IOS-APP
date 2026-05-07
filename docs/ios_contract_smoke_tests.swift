import Foundation

func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let data = Data(json.utf8)
    return try JSONDecoder().decode(type, from: data)
}

let publicATS = """
{
  "success": true,
  "sessionId": "anon-session",
  "score": { "overall": 74, "timestamp": "2026-05-05T08:00:00Z" },
  "preview": {
    "topIssues": [{ "message": "Add role-specific keywords", "severity": "medium" }],
    "totalIssues": 4,
    "lockedCount": 1
  },
  "quickWins": [{ "title": "Add SwiftUI", "impact": "high" }],
  "checksRemaining": 4
}
"""

let applications = """
{
  "success": true,
  "applications": [{
    "id": "app-1",
    "job_title": "iOS Engineer",
    "company_name": "Acme",
    "applied_date": "2026-05-05T08:00:00Z",
    "status": "applied",
    "ats_score": 91,
    "source_url": "https://linkedin.com/jobs/view/123",
    "optimization_id": "opt-1"
  }]
}
"""

let review = """
{
  "review": {
    "id": "review-1",
    "resume_id": "resume-1",
    "jd_id": "jd-1",
    "optimized_resume_json": {
      "summary": "Mobile engineer focused on SwiftUI.",
      "skills": ["Swift", "SwiftUI"]
    },
    "grouped_changes_json": [
      { "id": "group-1", "original": "Built apps", "optimized": "Built SwiftUI apps" }
    ],
    "ats_preview_json": { "after": 88 },
    "applied_at": null
  },
  "resume": { "filename": "resume.pdf", "raw_text": "raw" },
  "jobDescription": {
    "title": "iOS Engineer",
    "company": "Acme",
    "source_url": "https://linkedin.com/jobs/view/123"
  }
}
"""

let optimizations = """
{
  "success": true,
  "optimizations": [{
    "id": 42,
    "createdAt": "2026-05-05T08:00:00Z",
    "jobTitle": "iOS Engineer",
    "company": "Acme",
    "matchScore": 92,
    "status": "completed",
    "jobUrl": "https://linkedin.com/jobs/view/123",
    "templateKey": "natural",
    "resumeId": "resume-1",
    "jobDescriptionId": "jd-1",
    "rewriteData": { "summary": "Optimized summary" }
  }]
}
"""

let templates = """
{
  "templates": [{
    "id": "template-1",
    "slug": "natural",
    "name": "Natural",
    "description": "Clean ATS-safe resume",
    "category": "modern",
    "is_premium": false,
    "ats_score": 95
  }]
}
"""

@main
struct IOSContractSmokeTests {
    static func main() throws {
        let atsResult = try decode(ATSScoreResult.self, publicATS)
        precondition(atsResult.score?.overall == 74)
        precondition(atsResult.preview?.topIssues.count == 1)

        let appResult = try decode(ApplicationsResponse.self, applications)
        precondition(appResult.applications.first?.optimizationId == "opt-1")

        let reviewResult = try decode(OptimizationReviewResponse.self, review)
        precondition(reviewResult.review.id == "review-1")
        precondition(reviewResult.jobDescription?.sourceURL?.contains("linkedin") == true)

        let historyResult = try decode(OptimizationHistoryResponse.self, optimizations)
        precondition(historyResult.resolvedOptimizations.first?.id == "42")
        precondition(historyResult.resolvedOptimizations.first?.rewriteData != nil)

        let templatesResult = try decode(DesignTemplatesResponse.self, templates)
        precondition(templatesResult.templates.first?.name == "Natural")

        print("iOS contract smoke tests passed")
    }
}
