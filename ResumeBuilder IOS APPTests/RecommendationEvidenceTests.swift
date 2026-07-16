import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 9 — evidence-backed Accept/Skip recommendations.
///
/// Contract: `docs/specs/drafts/recommendation-evidence-backend-contract.md`
/// (APPROVED 2026-07-16, alternative B). v1 extracts evidence on-device from
/// text the review endpoint already delivers; every quote must be a verbatim
/// substring of its source, bounded, and never fabricated.
@MainActor
final class RecommendationEvidenceTests: XCTestCase {

    private let jobText = """
    Senior iOS Engineer — Mobility Team

    We are looking for someone with 5+ years of Swift experience building \
    consumer apps. You will own the offline-first sync architecture and lead \
    accessibility compliance across the app. Experience with Core Data and \
    CloudKit is required. Familiarity with fastlane deployment pipelines is a plus.
    """

    private let resumeText = """
    JANE DOE
    Senior iOS Developer

    Built consumer apps in Swift for 6 years across three product teams.
    Designed the offline-first sync architecture for a note-taking app with \
    2M downloads. Championed accessibility compliance, shipping full VoiceOver \
    coverage. Automated releases with fastlane deployment pipelines.
    """

    // MARK: - Verbatim guarantee

    func testEveryJobQuoteIsAVerbatimSubstringOfTheJobText() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Led the offline-first sync architecture and accessibility compliance efforts.",
            jobText: jobText,
            resumeText: nil
        )
        XCTAssertFalse(evidence.jobQuotes.isEmpty, "Shared phrases must produce job evidence.")
        for quote in evidence.jobQuotes {
            XCTAssertTrue(jobText.contains(quote), "Quote must be verbatim from the job text: \(quote)")
        }
    }

    func testEveryResumeQuoteIsAVerbatimSubstringOfTheResumeText() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Led the offline-first sync architecture with fastlane deployment pipelines.",
            jobText: nil,
            resumeText: resumeText
        )
        XCTAssertFalse(evidence.resumeQuotes.isEmpty, "Shared phrases must produce résumé evidence.")
        for quote in evidence.resumeQuotes {
            XCTAssertTrue(resumeText.contains(quote), "Quote must be verbatim from the résumé text: \(quote)")
        }
    }

    // MARK: - No fabrication

    func testUnrelatedTextsProduceNoEvidence() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Orchestrated quantum blockchain synergies for underwater basket weaving.",
            jobText: jobText,
            resumeText: resumeText
        )
        XCTAssertTrue(evidence.isEmpty, "No verbatim support means no evidence — never fabricate.")
    }

    func testMissingSourcesProduceNoEvidence() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Led accessibility compliance.",
            jobText: nil,
            resumeText: nil
        )
        XCTAssertTrue(evidence.isEmpty)

        let emptySources = RecommendationEvidence.extract(
            afterExcerpt: "Led accessibility compliance.",
            jobText: "",
            resumeText: "   "
        )
        XCTAssertTrue(emptySources.isEmpty)
    }

    func testStopwordOnlyOverlapProducesNoEvidence() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "You will be there with the team and for the app.",
            jobText: jobText,
            resumeText: nil
        )
        XCTAssertTrue(evidence.jobQuotes.isEmpty, "Stopword overlap is not evidence.")
    }

    // MARK: - Bounds

    func testQuoteCountAndLengthAreBounded() {
        let repeatedJob = Array(repeating: jobText, count: 6).joined(separator: "\n")
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Swift experience, offline-first sync architecture, accessibility compliance, Core Data, CloudKit, fastlane deployment pipelines.",
            jobText: repeatedJob,
            resumeText: nil
        )
        XCTAssertLessThanOrEqual(evidence.jobQuotes.count, RecommendationEvidence.maxQuotesPerSide)
        for quote in evidence.jobQuotes {
            XCTAssertLessThanOrEqual(quote.count, RecommendationEvidence.maxQuoteLength)
            XCTAssertTrue(repeatedJob.contains(quote))
        }
    }

    func testQuotesAreNotDuplicated() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "Swift experience with Core Data and CloudKit plus more Swift experience.",
            jobText: jobText,
            resumeText: nil
        )
        XCTAssertEqual(evidence.jobQuotes.count, Set(evidence.jobQuotes).count, "Quotes must be unique.")
    }

    // MARK: - Case-insensitive matching, source-cased output

    func testCaseInsensitiveMatchReturnsSourceCasedQuote() {
        let evidence = RecommendationEvidence.extract(
            afterExcerpt: "deep experience with core data and cloudkit integrations",
            jobText: jobText,
            resumeText: nil
        )
        XCTAssertFalse(evidence.jobQuotes.isEmpty)
        for quote in evidence.jobQuotes {
            XCTAssertTrue(jobText.contains(quote), "Quote must keep the source's original casing: \(quote)")
        }
    }

    // MARK: - Backend evidence preference (v2 upgrade path)

    func testValidBackendEvidenceIsPreferredOverLocalExtraction() throws {
        let backend = try decodeEvidence(
            """
            {
              "version": 1,
              "job": [{ "quote": "Core Data and CloudKit is required", "source": "job_description" }],
              "resume": []
            }
            """
        )
        let evidence = RecommendationEvidence.resolve(
            backend: backend,
            afterExcerpt: "Led the offline-first sync architecture.",
            jobText: jobText,
            resumeText: resumeText
        )
        XCTAssertEqual(evidence.jobQuotes, ["Core Data and CloudKit is required"])
        XCTAssertTrue(evidence.resumeQuotes.isEmpty, "Validated backend evidence must be used as delivered, not mixed with local extraction.")
    }

    func testNonVerbatimBackendQuoteIsDroppedAndLocalExtractionRuns() throws {
        let backend = try decodeEvidence(
            """
            {
              "version": 1,
              "job": [{ "quote": "This sentence is not in the job post.", "source": "job_description" }],
              "resume": []
            }
            """
        )
        let evidence = RecommendationEvidence.resolve(
            backend: backend,
            afterExcerpt: "Led the offline-first sync architecture.",
            jobText: jobText,
            resumeText: resumeText
        )
        XCTAssertFalse(evidence.jobQuotes.contains("This sentence is not in the job post."), "A quote that fails verbatim re-validation must never render.")
        XCTAssertFalse(evidence.isEmpty, "With no valid backend quotes, local extraction is the fallback.")
        for quote in evidence.jobQuotes { XCTAssertTrue(jobText.contains(quote)) }
    }

    func testUnknownBackendVersionFallsBackToLocalExtraction() throws {
        let backend = try decodeEvidence(
            """
            {
              "version": 99,
              "job": [{ "quote": "Core Data and CloudKit is required", "source": "job_description" }]
            }
            """
        )
        let evidence = RecommendationEvidence.resolve(
            backend: backend,
            afterExcerpt: "Led the offline-first sync architecture.",
            jobText: jobText,
            resumeText: resumeText
        )
        XCTAssertFalse(evidence.jobQuotes.contains("Core Data and CloudKit is required"), "An unknown evidence version is treated as absent.")
    }

    func testAbsentBackendEvidenceUsesLocalExtraction() {
        let evidence = RecommendationEvidence.resolve(
            backend: nil,
            afterExcerpt: "Led the offline-first sync architecture.",
            jobText: jobText,
            resumeText: resumeText
        )
        XCTAssertFalse(evidence.isEmpty)
    }

    // MARK: - Decoding compatibility

    func testGroupWithoutEvidenceKeyStillDecodes() throws {
        let json = """
        {
          "id": "skills",
          "section": "skills",
          "title": "Prioritized role-relevant skills",
          "summary": "Highlights the strongest keywords first.",
          "before_excerpt": "Swift",
          "after_excerpt": "Swift, Core Data, CloudKit"
        }
        """
        let group = try JSONDecoder().decode(ReviewChangeGroupDTO.self, from: Data(json.utf8))
        XCTAssertNil(group.evidence, "Pre-contract reviews decode with no evidence — compatibility is bidirectional.")
    }

    func testGroupWithEvidenceKeyDecodesQuotes() throws {
        let json = """
        {
          "id": "skills",
          "section": "skills",
          "title": "Prioritized role-relevant skills",
          "summary": "Highlights the strongest keywords first.",
          "before_excerpt": "Swift",
          "after_excerpt": "Swift, Core Data, CloudKit",
          "evidence": {
            "version": 1,
            "job": [{ "quote": "Core Data and CloudKit is required", "source": "job_description" }],
            "resume": [{ "quote": "Built consumer apps in Swift", "source": "resume" }]
          }
        }
        """
        let group = try JSONDecoder().decode(ReviewChangeGroupDTO.self, from: Data(json.utf8))
        XCTAssertEqual(group.evidence?.version, 1)
        XCTAssertEqual(group.evidence?.job?.first?.quote, "Core Data and CloudKit is required")
        XCTAssertEqual(group.evidence?.resume?.first?.quote, "Built consumer apps in Swift")
    }

    func testJobDescriptionDTODecodesDeliveredTextAdditively() throws {
        let withText = """
        { "title": "Senior iOS Engineer", "company": "Acme", "raw_text": "raw JD", "clean_text": "clean JD" }
        """
        let full = try JSONDecoder().decode(OptimizationReviewJobDescriptionDTO.self, from: Data(withText.utf8))
        XCTAssertEqual(full.rawText, "raw JD")
        XCTAssertEqual(full.cleanText, "clean JD")

        let withoutText = """
        { "title": "Senior iOS Engineer", "company": "Acme" }
        """
        let minimal = try JSONDecoder().decode(OptimizationReviewJobDescriptionDTO.self, from: Data(withoutText.utf8))
        XCTAssertNil(minimal.rawText)
        XCTAssertNil(minimal.cleanText)
    }

    // MARK: - Evidence never auto-approves

    func testEvidencePresenceDoesNotRelaxFactualConfirmation() {
        // A title-adjacent change stays confirmation-gated regardless of evidence.
        let assessment = RecommendationSafetyPolicy.assess(
            before: "iOS Developer",
            after: "Senior iOS Engineer",
            context: "contact\nUpdated headline details\nAligns headline-level details with the job target."
        )
        XCTAssertTrue(assessment.requiresExplicitConfirmation)
        XCTAssertFalse(
            assessment.defaultIncluded(reviewHasNonPositiveDelta: false),
            "Factual changes never default on — evidence informs, it does not approve."
        )
    }

    // MARK: - Helpers

    private func decodeEvidence(_ json: String) throws -> ReviewEvidenceDTO {
        try JSONDecoder().decode(ReviewEvidenceDTO.self, from: Data(json.utf8))
    }
}
