import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// G2b, "Add only if true" on iOS (market play plan, 2026-10-14).
///
/// The web optimizer holds back job-post phrases the résumé never states and
/// offers each one as "Add only if true", unselected, when the client sends
/// `confirmJobPhrases: true` (web `optimize-pipeline.ts`, PR #169). iOS used to
/// apply every review group, so sending the flag without a screen would have
/// confirmed every held claim for the user. These tests pin the request, the
/// response mapping and the rule that only the user can confirm a claim.
@MainActor
final class AddOnlyIfTrueTests: XCTestCase {

    private func envelope(_ groups: String) throws -> OptimizationReviewEnvelope {
        let json = """
        {"review": {"id": "review-1", "grouped_changes_json": [\(groups)], "ats_preview_json": {"before": 45, "after": 50, "delta": 5}}}
        """
        return try JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(json.utf8))
    }

    private let summaryGroup = """
    {"id": "summary", "section": "summary", "title": "Summary", "summary": "Sharper opening.",
     "before_excerpt": "Old", "after_excerpt": "New", "reason_tags": ["clarity"]}
    """
    private let experienceGroup = """
    {"id": "experience", "section": "experience", "title": "Experience", "summary": "Stronger bullets.",
     "before_excerpt": "Old", "after_excerpt": "New"}
    """
    private let experienceClaim = """
    {"id": "confirm-1", "section": "experience", "title": "Add only if true",
     "summary": "Matches the job, but your resume does not say it.",
     "before_excerpt": "Built weekly sales dashboards.",
     "after_excerpt": "Built weekly sales dashboards for non-technical stakeholders.",
     "reason_tags": ["confirm"],
     "confirm": {"requires": "experience", "index": 0, "kept": "Built weekly sales dashboards.",
                 "proposed": "Built weekly sales dashboards for non-technical stakeholders.",
                 "after": null, "terms": ["non-technical stakeholders"], "estimated_gain": 3}}
    """
    private let projectsClaim = """
    {"id": "confirm-2", "section": "projects", "title": "Add only if true", "summary": "",
     "before_excerpt": "", "after_excerpt": "Led a regional sales review.", "reason_tags": ["confirm"],
     "confirm": {"requires": "projects", "index": 0, "kept": null, "proposed": "Led a regional sales review.",
                 "after": null, "terms": ["regional"], "estimated_gain": null}}
    """
    private let standaloneClaim = """
    {"id": "confirm-3", "section": "summary", "title": "Add only if true", "summary": "",
     "before_excerpt": "", "after_excerpt": "Presents to sales leadership.", "reason_tags": ["confirm"],
     "confirm": {"requires": "certifications", "index": 0, "kept": null, "proposed": "Presents to sales leadership.",
                 "after": null, "terms": ["sales leadership"], "estimated_gain": 2, "standalone": true}}
    """

    // MARK: Request

    func testOptimizeRequestAsksTheServerToHoldJobPhrases() {
        let body = OptimizeRequestBody.build(resumeId: "resume-1", jobDescriptionId: "job-1")
        XCTAssertEqual(body["confirmJobPhrases"] as? Bool, true)
    }

    // MARK: Response mapping

    func testDecodesAHeldClaim() throws {
        let review = try envelope([summaryGroup, experienceClaim].joined(separator: ",")).review
        let claim = try XCTUnwrap(review.groupedChanges.last?.confirm)

        XCTAssertTrue(review.groupedChanges[1].isConfirmClaim)
        XCTAssertFalse(review.groupedChanges[0].isConfirmClaim)
        XCTAssertEqual(claim.requires, "experience")
        XCTAssertEqual(claim.kept, "Built weekly sales dashboards.")
        XCTAssertEqual(claim.proposed, "Built weekly sales dashboards for non-technical stakeholders.")
        XCTAssertEqual(claim.terms, ["non-technical stakeholders"])
        XCTAssertEqual(claim.estimatedGain, 3)
        XCTAssertFalse(claim.standalone)
    }

    func testAGroupFromBeforeTheContractHasNoClaim() throws {
        let review = try envelope(experienceGroup).review
        XCTAssertNil(review.groupedChanges[0].confirm)
        XCTAssertFalse(review.groupedChanges[0].isConfirmClaim)
    }

    // MARK: Selection

    func testNothingIsConfirmedUnlessTheUserConfirmsIt() throws {
        let env = try envelope([summaryGroup, experienceGroup, experienceClaim, standaloneClaim].joined(separator: ","))
        XCTAssertEqual(ConfirmPhraseSelection.approvedGroupIds(in: env, confirmed: []), ["summary", "experience"])
    }

    func testConfirmedClaimsJoinEveryChange() throws {
        let env = try envelope([summaryGroup, experienceGroup, experienceClaim, standaloneClaim].joined(separator: ","))
        XCTAssertEqual(
            ConfirmPhraseSelection.approvedGroupIds(in: env, confirmed: ["confirm-1", "confirm-3"]),
            ["summary", "experience", "confirm-1", "confirm-3"]
        )
    }

    func testOnlyClaimsTheUserCanUseAreAsked() throws {
        // confirm-2 edits a projects change that is not in this review and is not
        // standalone, so there is nothing to add it to: never asked, never sent.
        let env = try envelope([summaryGroup, experienceGroup, experienceClaim, projectsClaim, standaloneClaim].joined(separator: ","))
        XCTAssertEqual(ConfirmPhraseSelection.claims(in: env).map(\.id), ["confirm-1", "confirm-3"])
        XCTAssertEqual(
            ConfirmPhraseSelection.approvedGroupIds(in: env, confirmed: ["confirm-2", "made-up", "confirm-1"]),
            ["summary", "experience", "confirm-1"]
        )
    }

    func testAReviewWithoutClaimsAsksNothing() throws {
        let env = try envelope([summaryGroup, experienceGroup].joined(separator: ","))
        XCTAssertTrue(ConfirmPhraseSelection.claims(in: env).isEmpty)
    }

    func testDiagnosisListsOnlyTheChangesThatWereApplied() throws {
        let env = try envelope([summaryGroup, experienceClaim].joined(separator: ","))
        XCTAssertEqual(AppliedChangesViewModel.appliedGroups(in: env).map(\.id), ["summary"])
    }

    // MARK: Copy

    private func extractKey(_ key: LocalizedStringKey) -> String {
        for child in Mirror(reflecting: key).children where child.label == "key" {
            if let value = child.value as? String { return value }
        }
        XCTFail("Could not extract key from LocalizedStringKey")
        return ""
    }

    func testEveryLineIsTranslatedToHebrew() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: path))
        let keys = AddOnlyIfTrueCopy.all.map(extractKey) + [AddOnlyIfTrueCopy.gainFormat]

        for key in keys {
            let translated = hebrew.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(translated, key, "Hebrew falls back to English for \(key)")
            XCTAssertTrue(
                translated.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) },
                "Hebrew translation has no Hebrew characters: \(translated)"
            )
        }
    }
}
