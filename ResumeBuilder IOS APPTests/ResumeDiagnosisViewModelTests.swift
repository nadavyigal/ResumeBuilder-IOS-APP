import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ResumeDiagnosisViewModelTests: XCTestCase {
    func testMapperUsesATSBlockersAsTopGaps() {
        let diagnosis = ResumeDiagnosisMapper.make(
            matchScore: 54,
            potentialScore: 82,
            blockers: [
                ATSOptimizationBlocker(
                    id: "kw",
                    category: "keywords",
                    title: "Missing product analytics keywords",
                    detail: "The job asks for analytics ownership.",
                    suggestedAction: "Add truthful product analytics language where it matches your work.",
                    estimatedGain: 12,
                    severity: "high"
                ),
                ATSOptimizationBlocker(
                    id: "metrics",
                    category: "experience",
                    title: "Achievements are too generic",
                    detail: "Several bullets lack outcomes.",
                    suggestedAction: "Add measurable business outcomes.",
                    estimatedGain: 8,
                    severity: "medium"
                ),
            ],
            sections: [],
            jobTitle: "Product Analyst",
            company: "Acme"
        )

        XCTAssertEqual(diagnosis.matchScore, 54)
        XCTAssertEqual(diagnosis.potentialScore, 82)
        XCTAssertEqual(diagnosis.topGaps.count, 2)
        XCTAssertEqual(diagnosis.topGaps.first?.title, "Missing product analytics keywords")
        XCTAssertEqual(diagnosis.topGaps.first?.severity, .high)
        XCTAssertTrue(diagnosis.scoreNote.lowercased().contains("not a hiring guarantee"))
    }

    func testMapperDerivesMissingKeywordsFromKeywordBlockers() {
        let diagnosis = ResumeDiagnosisMapper.make(
            matchScore: 40,
            potentialScore: nil,
            blockers: [
                ATSOptimizationBlocker(
                    id: "kw",
                    category: "keywords",
                    title: "Missing 7 required cloud keywords",
                    suggestedAction: "Add the cloud terms only if truthful.",
                    severity: "high"
                )
            ],
            sections: [],
            jobTitle: nil,
            company: nil
        )

        XCTAssertEqual(diagnosis.missingKeywords.count, 1)
        XCTAssertEqual(diagnosis.missingKeywords.first?.importance, .high)
        XCTAssertFalse(diagnosis.missingKeywords.first?.keyword.lowercased().contains("missing") == true)
        XCTAssertFalse(diagnosis.missingKeywords.first?.keyword.lowercased().contains("keyword") == true)
    }

    func testMapperDoesNotFabricateOriginalBullet() throws {
        let diagnosis = ResumeDiagnosisMapper.make(
            matchScore: 61,
            potentialScore: 78,
            blockers: [],
            sections: [
                OptimizedResumeSection(
                    id: "exp",
                    type: .experience,
                    body: "Built weekly reporting workflows that helped leadership prioritize renewal actions.",
                    status: "optimized"
                )
            ],
            jobTitle: "Operations Manager",
            company: nil
        )

        let rewrite = try XCTUnwrap(diagnosis.beforeAfter.first)
        XCTAssertNil(rewrite.before)
        XCTAssertEqual(rewrite.after, "Built weekly reporting workflows that helped leadership prioritize renewal actions")
        XCTAssertTrue(rewrite.explanation.contains("Review every fact"))
    }

    func testBackendDiagnosisDecodesSnakeCaseWithoutIds() throws {
        let json = """
        {
          "match_score": 54,
          "potential_score": 82,
          "score_note": "Estimated guidance only.",
          "top_gaps": [
            {
              "title": "Missing analytics keywords",
              "explanation": "The job asks for analytics ownership.",
              "severity": "critical"
            }
          ],
          "missing_keywords": [
            {
              "keyword": "Product analytics",
              "importance": "required",
              "reason": "Repeated in the target job."
            }
          ],
          "recruiter_review": {
            "impression": "Strong operations background, but product ownership is unclear.",
            "strengths": ["Operations"],
            "concerns": ["Missing metrics"],
            "next_fix": "Rewrite the summary around the target job."
          },
          "before_after": [
            {
              "original_bullet": "Responsible for reports",
              "improved_bullet": "Built reporting workflows that helped leaders prioritize renewal actions.",
              "explanation": "Adds action, context, and impact."
            }
          ],
          "confidence_checklist": [
            {
              "title": "Includes priority keywords",
              "is_complete": true,
              "explanation": "More aligned with the target role."
            }
          ]
        }
        """.data(using: .utf8)!

        let diagnosis = try JSONDecoder().decode(ResumeDiagnosis.self, from: json)

        XCTAssertEqual(diagnosis.matchScore, 54)
        XCTAssertEqual(diagnosis.potentialScore, 82)
        XCTAssertEqual(diagnosis.topGaps.first?.severity, .high)
        XCTAssertEqual(diagnosis.missingKeywords.first?.importance, .high)
        XCTAssertEqual(diagnosis.recruiterReview.nextFix, "Rewrite the summary around the target job.")
        XCTAssertEqual(diagnosis.beforeAfter.first?.before, "Responsible for reports")
        XCTAssertEqual(diagnosis.beforeAfter.first?.after, "Built reporting workflows that helped leaders prioritize renewal actions.")
        XCTAssertEqual(diagnosis.confidenceChecklist.first?.isComplete, true)
    }

    func testMapperFallsBackWhenDataIsSparse() {
        let diagnosis = ResumeDiagnosisMapper.make(
            matchScore: nil,
            potentialScore: nil,
            blockers: [],
            sections: [],
            jobTitle: nil,
            company: nil
        )

        XCTAssertEqual(diagnosis.matchScore, 0)
        XCTAssertEqual(diagnosis.topGaps.count, 3)
        XCTAssertTrue(diagnosis.beforeAfter.isEmpty)
        XCTAssertFalse(diagnosis.confidenceChecklist.isEmpty)
        XCTAssertTrue(diagnosis.recruiterReview.impression.contains("target role"))
    }

    func testViewModelStartsEmptyWithoutOptimizationId() {
        let vm = ResumeDiagnosisViewModel(optimizationId: nil)

        XCTAssertTrue(vm.isEmpty)
        XCTAssertNil(vm.diagnosis)
        XCTAssertFalse(vm.isLoading)
    }
}
