import XCTest
@testable import ResumeBuilder_IOS_APP

/// The Diagnosis screen tells one score story, from stored values only.
///
/// On device 2026-10-19 (optimization 366eb3be, review run abea9106) the ring
/// said 67 while "What changed" said "Original score 45% -> Match score 49%".
/// 67 is the stored result (`ats_score_optimized`); 49 is the review's
/// projection, made before the apply. Two numbers for the same résumé, and the
/// lower one labelled as the match.
@MainActor
final class DiagnosisScoreStoryTests: XCTestCase {
    /// The review the server stored for that run: projection 45 -> 49.
    private let reviewJSON = """
    {"review": {"id": "abea9106-e90c-45fd-9312-2bd26f6d5698",
      "optimization_id": "366eb3be-3171-4869-8ec5-0414988e4b34",
      "ats_preview_json": {"before": 45, "after": 49, "delta": 4},
      "grouped_changes_json": [
        {"id": "summary", "section": "summary", "title": "Sharper professional summary",
         "summary": "Clarifies your value proposition for the target role.",
         "before_excerpt": "Sales manager.", "after_excerpt": "Sales manager who built a partner pipeline."},
        {"id": "experience", "section": "experience", "title": "Stronger experience bullets",
         "summary": "", "before_excerpt": "Did sales.", "after_excerpt": "Closed 14 accounts."}
      ]}}
    """

    /// The optimization detail for the same run: stored 45 -> 67. The
    /// `diagnosis.potential_score` is what an older server path sent; it must
    /// not come back as a projection after the apply.
    private let detailJSON = """
    {"sections": [], "ats_score_before": 45, "ats_score_after": 67,
     "ats_blockers": [],
     "diagnosis": {"match_score": 45, "potential_score": 49, "score_note": ""}}
    """

    private func decodeReview() throws -> OptimizationReviewEnvelope {
        try JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(reviewJSON.utf8))
    }

    private func decodeDetail() throws -> OptimizationDetailDTO {
        try JSONDecoder().decode(OptimizationDetailDTO.self, from: Data(detailJSON.utf8))
    }

    func testScreenShowsStoredResultUpFromStoredStart() throws {
        let review = try decodeReview()
        let detail = try decodeDetail()
        XCTAssertEqual(review.review.atsPreview?.after, 49, "fixture: the projection the screen used to show")

        let diagnosis = ResumeDiagnosisMapper.make(from: detail)

        XCTAssertEqual(diagnosis.matchScore, 67, "the headline is the stored result")
        XCTAssertEqual(diagnosis.startingScore, 45, "the start is the stored original")
        XCTAssertEqual(diagnosis.displayedStartingScore, 45, "a +22 lift is worth showing")
        XCTAssertNil(diagnosis.potentialScore, "no projection after the apply")
    }

    /// "What changed" lists the applied sections from the review. It reads
    /// nothing else from it: the projected 49 used to become its "Match score".
    func testWhatChangedListsTheReviewSections() throws {
        let changes = AppliedChangesViewModel(envelope: try decodeReview())

        XCTAssertEqual(changes.groups.map(\.id), ["summary", "experience"])
        XCTAssertEqual(changes.groups.map { ReviewSectionName.label(for: $0.section) }, ["Summary", "Experience"])
    }

    func testSmallLiftShowsNoStartingScore() throws {
        let json = #"{"sections": [], "ats_score_before": 45, "ats_score_after": 48}"#
        let detail = try JSONDecoder().decode(OptimizationDetailDTO.self, from: Data(json.utf8))

        let diagnosis = ResumeDiagnosisMapper.make(from: detail)

        XCTAssertEqual(diagnosis.matchScore, 48)
        XCTAssertEqual(diagnosis.startingScore, 45)
        XCTAssertNil(diagnosis.displayedStartingScore, "same rule as the Optimized tab: under +5 is not shown as a pair")
    }

    func testDropShowsNoStartingScore() throws {
        let json = #"{"sections": [], "ats_score_before": 52, "ats_score_after": 47}"#
        let detail = try JSONDecoder().decode(OptimizationDetailDTO.self, from: Data(json.utf8))

        XCTAssertNil(ResumeDiagnosisMapper.make(from: detail).displayedStartingScore)
    }

    func testNoStoredResultShowsTheOriginalWithNoStart() throws {
        let json = #"{"sections": [], "ats_score_before": 45}"#
        let detail = try JSONDecoder().decode(OptimizationDetailDTO.self, from: Data(json.utf8))

        let diagnosis = ResumeDiagnosisMapper.make(from: detail)

        XCTAssertEqual(diagnosis.matchScore, 45)
        XCTAssertNil(diagnosis.startingScore, "the start is only meaningful next to a stored result")
        XCTAssertNil(diagnosis.displayedStartingScore)
    }

    func testStartingScoreSurvivesEncodeDecode() throws {
        let diagnosis = ResumeDiagnosisMapper.make(from: try decodeDetail())
        let data = try JSONEncoder().encode(diagnosis)
        let decoded = try JSONDecoder().decode(ResumeDiagnosis.self, from: data)

        XCTAssertEqual(decoded.startingScore, 45)
        XCTAssertEqual(decoded.matchScore, 67)
    }

    func testSectionNamesAreHuman() {
        XCTAssertEqual(ReviewSectionName.label(for: "summary"), "Summary")
        XCTAssertEqual(ReviewSectionName.label(for: "experience"), "Experience")
        XCTAssertEqual(ReviewSectionName.label(for: "skills"), "Skills")
        XCTAssertEqual(ReviewSectionName.label(for: "education"), "Education")
        XCTAssertEqual(ReviewSectionName.label(for: "certifications"), "Certifications")
        XCTAssertEqual(ReviewSectionName.label(for: "projects"), "Projects")
        XCTAssertEqual(ReviewSectionName.label(for: "contact"), "Contact details")
        XCTAssertEqual(ReviewSectionName.label(for: "  SUMMARY "), "Summary")
        XCTAssertEqual(ReviewSectionName.label(for: "volunteer_work"), "Volunteer work", "unknown names still read as words")
        XCTAssertEqual(ReviewSectionName.label(for: ""), "")
    }

    func testDiagnosisChecklistNeverSaysATS() {
        let items = ConfidenceItem.defaultChecklist(matchScore: 67, hasKeywords: true, hasRewrite: true)
        for item in items {
            XCTAssertFalse(item.title.contains("ATS"), item.title)
            XCTAssertFalse((item.explanation ?? "").contains("ATS"), item.explanation ?? "")
        }
    }
}
