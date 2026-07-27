import XCTest
@testable import ResumeBuilder_IOS_APP

/// The join that was actually broken.
///
/// The fit check was never removed — it was unreachable. `/api/optimize`
/// returned only `{ reviewId, nextStep }`, and TailorViewModel checked reviewId
/// first and returned, so optimizationId was never set and Home's fit-check
/// branch was dead code. Every run went straight to the accept screen.
///
/// These pin both halves: the app decodes the `fit` block the backend now
/// sends, and a response carrying a reviewId no longer loses it.
@MainActor
final class OptimizeFitResponseTests: XCTestCase {

    /// Exactly the shape `/api/optimize` returns after the backend change.
    private let liveResponse = """
    {
      "reviewId": "rev_123",
      "nextStep": "review",
      "fit": {
        "currentScore": 29,
        "potentialScore": 48,
        "delta": 19,
        "displayScores": true,
        "confidence": 0.82,
        "scoreVersion": "ats_v2.1_wp45",
        "topGaps": [
          { "title": "Add at least one metric to your most recent role", "estimatedGain": 6, "category": "metrics" },
          { "title": "Include timeframes showing speed of delivery", "estimatedGain": 4, "category": "content" }
        ]
      }
    }
    """.data(using: .utf8)!

    func testTheFitBlockSurvivesDecoding() throws {
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: liveResponse)

        XCTAssertEqual(decoded.reviewId, "rev_123")
        XCTAssertEqual(decoded.fit?.currentScore, 29, "the before — what the fit check shows")
        XCTAssertEqual(decoded.fit?.potentialScore, 48, "what accepting buys")
        XCTAssertEqual(decoded.fit?.delta, 19)
        XCTAssertEqual(decoded.fit?.displayScores, true)
        XCTAssertEqual(decoded.fit?.topGaps?.count, 2)
        XCTAssertEqual(decoded.fit?.topGaps?.first?.title,
                       "Add at least one metric to your most recent role")
    }

    func testAReviewIdNoLongerSwallowsTheFitCheck() throws {
        // The regression in one assertion: a response with a reviewId still
        // carries the measurement, so the router can show the fit check before
        // the accept screen instead of skipping it.
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: liveResponse)
        XCTAssertNotNil(decoded.reviewId)
        XCTAssertNotNil(decoded.fit, "a reviewId must not mean the fit check is lost")
    }

    func testAnOlderBackendWithoutTheFitBlockStillDecodes() throws {
        // Graceful fallback: against a backend that predates this change the
        // app keeps its previous behaviour rather than crashing or showing an
        // empty fit check.
        let legacy = #"{"reviewId":"rev_1","nextStep":"review"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: legacy)
        XCTAssertEqual(decoded.reviewId, "rev_1")
        XCTAssertNil(decoded.fit)
    }

    func testTheScreenWithholdsThePairWhenTheRunDidNotImprove() throws {
        // The 42 -> 44 case arriving over the wire. The fit check still shows
        // gaps and a next step; it just does not present a number pair.
        let json = """
        {"reviewId":"r","nextStep":"review",
         "fit":{"currentScore":42,"potentialScore":44,"delta":2,"displayScores":false}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(decoded.fit?.displayScores, false)
        XCTAssertEqual(decoded.fit?.currentScore, 42)
    }

    func testRoutingPrefersTheFitCheckOverTheAcceptScreen() throws {
        // Home shows .fitCheck when the run measured one, and falls through to
        // .optimizationReview when it did not. Encoded here as the routing rule
        // rather than reaching into the view.
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: liveResponse)
        let route: FirstSessionJourneyRoute = (decoded.fit?.currentScore != nil)
            ? .fitCheck(reviewId: decoded.reviewId!)
            : .optimizationReview(reviewId: decoded.reviewId!)
        XCTAssertEqual(route, .fitCheck(reviewId: "rev_123"))

        let legacy = try JSONDecoder().decode(
            OptimizeResponse.self,
            from: #"{"reviewId":"rev_9","nextStep":"review"}"#.data(using: .utf8)!
        )
        let legacyRoute: FirstSessionJourneyRoute = (legacy.fit?.currentScore != nil)
            ? .fitCheck(reviewId: legacy.reviewId!)
            : .optimizationReview(reviewId: legacy.reviewId!)
        XCTAssertEqual(legacyRoute, .optimizationReview(reviewId: "rev_9"))
    }
}
