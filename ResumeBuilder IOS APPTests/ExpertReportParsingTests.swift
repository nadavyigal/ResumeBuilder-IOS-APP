import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ExpertReportParsingTests: XCTestCase {

    // MARK: - displayModel: full_resume_rewrite

    func testDisplayModel_acceptsBackendReportEnvelopeForFullResumeRewrite() {
        let output = JSONValue.object([
            "rewritten_resume": .object([
                "summary": .string("Rewritten for role fit.")
            ]),
            "report": .object([
                "headline": .string("Full resume rewrite completed"),
                "executive_summary": .string("The resume now emphasizes role-fit evidence."),
                "priority_actions": .array([.string("Review rewritten bullets for accuracy.")]),
                "evidence_gaps": .array([.string("Add exact team size.")]),
                "ats_impact_estimate": .object([
                    "before": .number(61.0),
                    "after": .number(73.0),
                    "delta": .number(12.0),
                    "confidence_note": .string("Estimated from keyword and evidence coverage.")
                ])
            ]),
            "missing_evidence": .array([.string("Add exact team size.")])
        ])

        let report = ExpertReportParsing.displayModel(from: output)
        XCTAssertEqual(report?.headline, "Full resume rewrite completed")
        XCTAssertEqual(report?.priorityActions, ["Review rewritten bullets for accuracy."])
        XCTAssertEqual(report?.evidenceGaps, ["Add exact team size."])
        XCTAssertEqual(report?.atsImpact?.after, 73.0)
    }

    // MARK: - parsedOutput: summary_options

    func testParseSummaryOptions_extractsStyleAndSummary() {
        let output = JSONValue.object([
            "summary_options": .array([
                .object([
                    "angle": .string("leadership"),
                    "summary": .string("A seasoned engineer."),
                    "rationale": .string("Best for manager-heavy roles.")
                ]),
                .object([
                    "angle": .string("results"),
                    "summary": .string("Delivered 40% revenue growth."),
                    "rationale": .string("Best for impact-heavy roles.")
                ])
            ]),
            "recommended_index": .number(1)
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.summaryOptions.count, 2)
        XCTAssertEqual(parsed.summaryOptions[0].style, "leadership")
        XCTAssertEqual(parsed.summaryOptions[0].summary, "A seasoned engineer.")
        XCTAssertEqual(parsed.summaryOptions[0].rationale, "Best for manager-heavy roles.")
        XCTAssertEqual(parsed.summaryOptions[1].style, "results")
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
                    "evidence_used": .array([.string("12-person team")]),
                    "missing_evidence_questions": .array([.string("What was the shipment timeline?")])
                ])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.bulletRewrites.count, 1)
        let rewrite = parsed.bulletRewrites[0]
        XCTAssertEqual(rewrite.originalBullet, "Managed team")
        XCTAssertEqual(rewrite.optimizedBullet, "Led 12-person team, shipping 3 features per sprint")
        XCTAssertEqual(rewrite.evidenceUsed, ["12-person team"])
        XCTAssertEqual(rewrite.missingEvidenceQuestions, ["What was the shipment timeline?"])
    }

    func testParseBulletRewrites_emptyReturnsEmpty() {
        let output = JSONValue.object(["bullet_rewrites": .array([])])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertTrue(parsed.bulletRewrites.isEmpty)
    }

    func testParseBulletRewrites_keepsMissingMetricsFallback() {
        let output = JSONValue.object([
            "bullet_rewrites": .array([
                .object([
                    "original_bullet": .string("Improved onboarding"),
                    "optimized_bullet": .string("Improved onboarding flow for new hires"),
                    "missing_metrics": .array([.string("baseline onboarding time")])
                ])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.bulletRewrites.first?.missingMetrics, ["baseline onboarding time"])
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
                "score_estimate": .object(["before": .number(64.0), "after": .number(72.0)]),
                "keyword_match_analysis": .array([
                    .object([
                        "keyword": .string("Kubernetes"),
                        "present": .bool(false),
                        "suggested_placement": .string("skills"),
                        "note": .string("Add only if truthful.")
                    ])
                ]),
                "recommended_keywords_to_add": .array([.string("Kubernetes"), .string("CI/CD")]),
                "section_heading_compliance": .array([.string("Use standard Experience heading")]),
                "format_guidance": .array([.string("Avoid tables")]),
                "acronym_coverage": .array([.string("Spell out CI/CD once")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertNotNil(parsed.atsReport)
        XCTAssertEqual(parsed.atsReport?.score, 72.0)
        XCTAssertEqual(parsed.atsReport?.scoreEstimate?.before, 64.0)
        XCTAssertEqual(parsed.atsReport?.keywordMatches.first?.keyword, "Kubernetes")
        XCTAssertEqual(parsed.atsReport?.keywordMatches.first?.present, false)
        XCTAssertEqual(parsed.atsReport?.keywordMatches.first?.suggestedPlacement, "skills")
        XCTAssertEqual(parsed.atsReport?.recommendedKeywordsToAdd, ["Kubernetes", "CI/CD"])
        XCTAssertEqual(parsed.atsReport?.sectionHeadingCompliance, ["Use standard Experience heading"])
        XCTAssertEqual(parsed.atsReport?.formatGuidance, ["Avoid tables"])
        XCTAssertEqual(parsed.atsReport?.acronymCoverage, ["Spell out CI/CD once"])
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
                .object([
                    "angle": .string("concise"),
                    "title": .string("Concise fit"),
                    "opening_paragraph": .string("Dear Hiring Manager,"),
                    "letter": .string("Dear Hiring Manager,\nI am excited to apply."),
                    "rationale": .string("Direct and brief.")
                ]),
                .object([
                    "angle": .string("impact"),
                    "title": .string("Impact fit"),
                    "opening_paragraph": .string("Hello,"),
                    "letter": .string("Hello,\nI can help your team ship faster."),
                    "rationale": .string("Highlights outcomes.")
                ])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.coverLetterVariants.count, 2)
        XCTAssertEqual(parsed.coverLetterVariants[0].tone, "concise")
        XCTAssertEqual(parsed.coverLetterVariants[0].title, "Concise fit")
        XCTAssertEqual(parsed.coverLetterVariants[0].openingParagraph, "Dear Hiring Manager,")
        XCTAssertEqual(parsed.coverLetterVariants[0].body, "Dear Hiring Manager,\nI am excited to apply.")
        XCTAssertEqual(parsed.coverLetterVariants[0].rationale, "Direct and brief.")
        XCTAssertEqual(parsed.coverLetterVariants[1].tone, "impact")
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

    func testParseCoverLetterVariants_keepsToneBodyFallback() {
        let output = JSONValue.object([
            "cover_letter_variants": .array([
                .object(["tone": .string("Formal"), "body": .string("Legacy body.")])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.coverLetterVariants.first?.tone, "Formal")
        XCTAssertEqual(parsed.coverLetterVariants.first?.body, "Legacy body.")
    }

    // MARK: - parsedOutput: screening_answers

    func testParseScreeningAnswers_extractsQuestionAndAnswer() {
        let output = JSONValue.object([
            "screening_answers": .array([
                .object([
                    "question": .string("Why do you want this role?"),
                    "answer": .string("I have 5 years in iOS."),
                    "evidence_used": .array([.string("5 years in iOS")]),
                    "confidence_note": .string("High confidence from resume evidence.")
                ])
            ])
        ])
        let parsed = ExpertReportParsing.parsedOutput(from: output)
        XCTAssertEqual(parsed.screeningAnswers.count, 1)
        XCTAssertEqual(parsed.screeningAnswers[0].question, "Why do you want this role?")
        XCTAssertEqual(parsed.screeningAnswers[0].answer, "I have 5 years in iOS.")
        XCTAssertEqual(parsed.screeningAnswers[0].evidenceUsed, ["5 years in iOS"])
        XCTAssertEqual(parsed.screeningAnswers[0].confidenceNote, "High confidence from resume evidence.")
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
