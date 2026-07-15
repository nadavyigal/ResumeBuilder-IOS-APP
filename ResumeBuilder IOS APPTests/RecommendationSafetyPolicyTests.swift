import XCTest
@testable import ResumeBuilder_IOS_APP

final class RecommendationSafetyPolicyTests: XCTestCase {
    func testPlaceholderOutputIsSuppressedAndCannotBeSelected() {
        let result = RecommendationSafetyPolicy.assess(
            before: "Led the support team.",
            after: "Led {team_size} support specialists.",
            context: "Impact rewrite"
        )

        XCTAssertTrue(result.isSuppressed)
        XCTAssertFalse(result.canSelect)
        XCTAssertFalse(result.defaultIncluded(reviewHasNonPositiveDelta: false))
        XCTAssertEqual(result.analyticsReason, "unresolved_placeholder")
    }

    func testTitleInflationDefaultsOffButCanBeExplicitlySelected() {
        let result = RecommendationSafetyPolicy.assess(
            before: "Software Engineer",
            after: "Senior Software Engineer",
            context: "Professional title"
        )

        XCTAssertTrue(result.requiresExplicitConfirmation)
        XCTAssertTrue(result.canSelect)
        XCTAssertFalse(result.defaultIncluded(reviewHasNonPositiveDelta: false))
        XCTAssertTrue(result.reasons.contains(.titleOrSeniority))
    }

    func testRemovedDateDefaultsOff() {
        let result = RecommendationSafetyPolicy.assess(
            before: "Acme · January 2022 – March 2024",
            after: "Acme",
            context: "Experience date"
        )

        XCTAssertTrue(result.requiresExplicitConfirmation)
        XCTAssertTrue(result.reasons.contains(.date))
        XCTAssertFalse(result.defaultIncluded(reviewHasNonPositiveDelta: false))
    }

    func testChangedMetricDefaultsOff() {
        let result = RecommendationSafetyPolicy.assess(
            before: "Improved conversion by 12%.",
            after: "Improved conversion by 30%.",
            context: "Achievement metric"
        )

        XCTAssertTrue(result.requiresExplicitConfirmation)
        XCTAssertTrue(result.reasons.contains(.numericalAchievement))
        XCTAssertFalse(result.defaultIncluded(reviewHasNonPositiveDelta: false))
    }

    func testEverySpecifiedFactualCategoryDefaultsOff() {
        let cases: [(context: String, before: String, after: String, reason: RecommendationSafetyPolicy.Reason)] = [
            ("Company", "Acme", "Globex", .company),
            ("Education degree", "BA", "MBA", .degree),
            ("Location", "Haifa", "Tel Aviv", .location),
            ("Contact email", "person@example.com", "other@example.com", .contact),
        ]

        for fixture in cases {
            let result = RecommendationSafetyPolicy.assess(
                before: fixture.before,
                after: fixture.after,
                context: fixture.context
            )
            XCTAssertTrue(result.reasons.contains(fixture.reason), "Missing \(fixture.reason)")
            XCTAssertFalse(result.defaultIncluded(reviewHasNonPositiveDelta: false))
        }
    }

    func testScoreRegressionStartsEveryChangeOff() {
        let score = RecommendationSafetyPolicy.assessScore(before: 53, after: 52)
        let safeRewrite = RecommendationSafetyPolicy.assess(
            before: "Owned weekly reports.",
            after: "Created and distributed weekly reports.",
            context: "Clarity"
        )

        XCTAssertTrue(score.isNonPositive)
        XCTAssertFalse(safeRewrite.defaultIncluded(reviewHasNonPositiveDelta: score.isNonPositive))
    }

    func testSafeRewriteWithImprovedScoreDefaultsOn() {
        let score = RecommendationSafetyPolicy.assessScore(before: 52, after: 53)
        let result = RecommendationSafetyPolicy.assess(
            before: "Owned weekly reports.",
            after: "Created and distributed weekly reports.",
            context: "Clarity"
        )

        XCTAssertFalse(score.isNonPositive)
        XCTAssertFalse(result.requiresExplicitConfirmation)
        XCTAssertTrue(result.defaultIncluded(reviewHasNonPositiveDelta: score.isNonPositive))
    }
}
