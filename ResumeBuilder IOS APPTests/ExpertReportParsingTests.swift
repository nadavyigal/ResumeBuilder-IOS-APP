import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ExpertReportParsingTests: XCTestCase {

    // MARK: - parsedOutput: summary_options

    func testParseSummaryOptions_extractsStyleAndSummary() {
        let output = JSONValue.object([
            "summary_options": .array([
                .object(["style": .string("Professional"), "summary": .string("A seasoned engineer.")]),
                .object(["style": .string("Results-focused"), "summary": .string("Delivered 40% revenue growth.")])
            ]),
            "recommended_index": .number(1)
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.summaryOptions.count, 2)
        XCTAssertEqual(parsed.summaryOptions[0].style, "Professional")
        XCTAssertEqual(parsed.summaryOptions[0].summary, "A seasoned engineer.")
        XCTAssertEqual(parsed.summaryOptions[1].style, "Results-focused")
        XCTAssertEqual(parsed.recommendedIndex, 1)
    }

    func testParseSummaryOptions_skipsMissingBody() {
        let output = JSONValue.object([
            "summary_options": .array([
                .object(["style": .string("Empty"), "summary": .string("")]),
                .object(["style": .string("Good"), "summary": .string("Real summary text.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.summaryOptions.count, 1)
        XCTAssertEqual(parsed.summaryOptions[0].style, "Good")
    }

    func testParseSummaryOptions_emptyArrayReturnsEmpty() {
        let output = JSONValue.object(["summary_options": .array([])])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertTrue(parsed.summaryOptions.isEmpty)
        XCTAssertNil(parsed.recommendedIndex)
    }

    // MARK: - parsedOutput: bullet_rewrites

    func testParseBulletRewrites_extractsBeforeAndAfter() {
        let output = JSONValue.object([
            "bullet_rewrites": .array([
                .object([
                    "original_bullet": .string("Managed team"),
                    "optimized_bullet": .string("Led 12-person team, shipping 3 features per sprint"),
                    "impact": .string("High"),
                    "missing_metrics": .array([.string("headcount"), .string("timeline")])
                ])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.bulletRewrites.count, 1)
        let rewrite = parsed.bulletRewrites[0]
        XCTAssertEqual(rewrite.originalBullet, "Managed team")
        XCTAssertEqual(rewrite.optimizedBullet, "Led 12-person team, shipping 3 features per sprint")
        XCTAssertEqual(rewrite.impact, "High")
        XCTAssertEqual(rewrite.missingMetrics, ["headcount", "timeline"])
    }

    func testParseBulletRewrites_emptyReturnsEmpty() {
        let output = JSONValue.object(["bullet_rewrites": .array([])])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertTrue(parsed.bulletRewrites.isEmpty)
    }

    func testParseBulletRewrites_skipsBothEmptyBullets() {
        let output = JSONValue.object([
            "bullet_rewrites": .array([
                .object(["original_bullet": .string(""), "optimized_bullet": .string("")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertTrue(parsed.bulletRewrites.isEmpty)
    }

    // MARK: - parsedOutput: ats_report

    func testParseATSReport_extractsKeywordsAndScore() {
        let output = JSONValue.object([
            "ats_report": .object([
                "score": .number(72.0),
                "recommended_keywords_to_add": .array([.string("Kubernetes"), .string("CI/CD")]),
                "keyword_placements": .array([.string("Add Kubernetes to Skills section")]),
                "missing_keywords": .array([.string("Docker")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertNotNil(parsed.atsReport)
        XCTAssertEqual(parsed.atsReport?.score, 72.0)
        XCTAssertEqual(parsed.atsReport?.recommendedKeywordsToAdd, ["Kubernetes", "CI/CD"])
        XCTAssertEqual(parsed.atsReport?.keywordPlacements, ["Add Kubernetes to Skills section"])
        XCTAssertEqual(parsed.atsReport?.missingKeywords, ["Docker"])
    }

    func testParseATSReport_nilWhenMissing() {
        let output = JSONValue.object(["summary_options": .array([])])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertNil(parsed.atsReport)
    }

    // MARK: - parsedOutput: cover_letter_variants

    func testParseCoverLetterVariants_extractsToneAndBody() {
        let output = JSONValue.object([
            "cover_letter_variants": .array([
                .object(["tone": .string("Formal"), "body": .string("Dear Hiring Manager,")]),
                .object(["tone": .string("Conversational"), "body": .string("Hi there,")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.coverLetterVariants.count, 2)
        XCTAssertEqual(parsed.coverLetterVariants[0].tone, "Formal")
        XCTAssertEqual(parsed.coverLetterVariants[0].body, "Dear Hiring Manager,")
        XCTAssertEqual(parsed.coverLetterVariants[1].tone, "Conversational")
    }

    func testParseCoverLetterVariants_skipsEmptyBody() {
        let output = JSONValue.object([
            "cover_letter_variants": .array([
                .object(["tone": .string("Empty"), "body": .string("")]),
                .object(["tone": .string("Good"), "body": .string("Real body.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.coverLetterVariants.count, 1)
        XCTAssertEqual(parsed.coverLetterVariants[0].tone, "Good")
    }

    // MARK: - parsedOutput: screening_answers

    func testParseScreeningAnswers_extractsQuestionAndAnswer() {
        let output = JSONValue.object([
            "screening_answers": .array([
                .object(["question": .string("Why do you want this role?"), "answer": .string("I have 5 years in iOS.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.screeningAnswers.count, 1)
        XCTAssertEqual(parsed.screeningAnswers[0].question, "Why do you want this role?")
        XCTAssertEqual(parsed.screeningAnswers[0].answer, "I have 5 years in iOS.")
    }

    func testParseScreeningAnswers_skipsEmptyAnswer() {
        let output = JSONValue.object([
            "screening_answers": .array([
                .object(["question": .string("Q1"), "answer": .string("")]),
                .object(["question": .string("Q2"), "answer": .string("Non-empty answer.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.screeningAnswers.count, 1)
        XCTAssertEqual(parsed.screeningAnswers[0].question, "Q2")
    }

    // MARK: - parsedOutput: empty / malformed

    func testParsedOutput_emptyOutputReturnsEmpty() {
        let output = JSONValue.object([:])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertTrue(parsed.summaryOptions.isEmpty)
        XCTAssertNil(parsed.recommendedIndex)
        XCTAssertTrue(parsed.bulletRewrites.isEmpty)
        XCTAssertNil(parsed.atsReport)
        XCTAssertTrue(parsed.coverLetterVariants.isEmpty)
        XCTAssertTrue(parsed.screeningAnswers.isEmpty)
    }

    func testParsedOutput_nonObjectRootReturnsEmpty() {
        let output = JSONValue.string("unexpected")
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed, ExpertOutputParsed.empty)
    }

    // MARK: - Selection index defaults

    func testRecommendedIndexDefaultsToNilWhenAbsent() {
        let output = JSONValue.object([
            "summary_options": .array([
                .object(["style": .string("Option A"), "summary": .string("Summary A.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertNil(parsed.recommendedIndex)
    }

    func testRecommendedIndexParsedFromNumber() {
        let output = JSONValue.object([
            "summary_options": .array([
                .object(["style": .string("A"), "summary": .string("S1.")]),
                .object(["style": .string("B"), "summary": .string("S2.")])
            ]),
            "recommended_index": .number(1)
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.recommendedIndex, 1)
    }

    // MARK: - ExpertRunUIState.parsedOutput

    func testExpertRunUIState_parsedOutputDelegatesToParsing() {
        let output = JSONValue.object([
            "bullet_rewrites": .array([
                .object([
                    "original_bullet": .string("Did stuff"),
                    "optimized_bullet": .string("Shipped feature X in 2 weeks")
                ])
            ])
        ])
        let state = ExpertRunUIState(
            workflowType: .achievementQuantifier,
            runId: "run-1",
            status: "completed",
            output: output,
            missingEvidence: [],
            needsUserInput: false
        )
        XCTAssertEqual(state.parsedOutput.bulletRewrites.count, 1)
        XCTAssertEqual(state.parsedOutput.bulletRewrites[0].optimizedBullet, "Shipped feature X in 2 weeks")
    }

    // MARK: - ExpertModesViewModel: selection tracking

    func testViewModel_setAndGetSelectedVariantIndex() {
        let vm = ExpertModesViewModel(
            optimizationId: "opt-1",
            resumeViewModel: nil
        )
        XCTAssertNil(vm.selectedVariantIndex(for: .professionalSummaryLab))
        vm.setSelectedVariantIndex(2, for: .professionalSummaryLab)
        XCTAssertEqual(vm.selectedVariantIndex(for: .professionalSummaryLab), 2)
    }

    func testViewModel_selectionIndependentPerType() {
        let vm = ExpertModesViewModel(
            optimizationId: "opt-1",
            resumeViewModel: nil
        )
        vm.setSelectedVariantIndex(0, for: .professionalSummaryLab)
        vm.setSelectedVariantIndex(1, for: .coverLetterArchitect)
        XCTAssertEqual(vm.selectedVariantIndex(for: .professionalSummaryLab), 0)
        XCTAssertEqual(vm.selectedVariantIndex(for: .coverLetterArchitect), 1)
    }
}
