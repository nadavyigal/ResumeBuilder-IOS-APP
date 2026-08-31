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

    /// The production break, 2026-08-31.
    ///
    /// `estimatedGain` is not an integer and has not been one since WP-59 S1
    /// (web #147, 2026-08-28). `estimateImpact` now returns
    /// `Math.round(value * 10) / 10`, and its own comment states every real
    /// value lands between 0.36 and 3.75. `expandKeywordSuggestion` floors the
    /// split gain to one decimal as well. Before WP-59 every suggestion was
    /// clamped to a flat integer 15, which is the only reason `Int?` ever
    /// worked and the only reason the fixture above still passes.
    ///
    /// A fractional gain makes `JSONDecoder` throw "Number 2.5 is not
    /// representable in Swift", which fails the whole `OptimizeResponse`
    /// decode, which `ResumeOptimizationService.optimize` catches as
    /// `DecodingError` and reports as "We couldn't parse the optimization
    /// response." Every optimization on production ends there.
    func testAFractionalGainDoesNotKillTheWholeResponse() throws {
        let live = """
        {
          "reviewId": "rev_777",
          "nextStep": "review",
          "fit": {
            "currentScore": 34,
            "potentialScore": 51,
            "delta": 17,
            "displayScores": true,
            "confidence": 0.74,
            "scoreVersion": "ats_v2.1_wp59",
            "topGaps": [
              { "title": "Add Kubernetes in context on your resume", "estimatedGain": 2.5, "category": "keywords" },
              { "title": "Add at least one metric to your most recent role", "estimatedGain": 3.75, "category": "metrics" },
              { "title": "Add Terraform in context on your resume", "estimatedGain": 0.6, "category": "keywords" }
            ]
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: live)

        XCTAssertEqual(decoded.reviewId, "rev_777", "the run must survive a fractional gain")
        XCTAssertEqual(decoded.fit?.currentScore, 34)
        XCTAssertEqual(decoded.fit?.topGaps?.count, 3)
        // Rounded for display, matching the ATSSuggestion decoder that already
        // solved this one struct away.
        XCTAssertEqual(decoded.fit?.topGaps?.first?.estimatedGain, 3, "2.5 rounds to 3")
        XCTAssertEqual(decoded.fit?.topGaps?[1].estimatedGain, 4, "3.75 rounds to 4")
        XCTAssertEqual(decoded.fit?.topGaps?[2].estimatedGain, 1, "0.6 rounds to 1")
    }

    /// An integer gain still decodes: older backends and whole-number values.
    func testAnIntegerGainStillDecodes() throws {
        let json = #"{"reviewId":"r","fit":{"topGaps":[{"title":"t","estimatedGain":6,"category":"metrics"}]}}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(decoded.fit?.topGaps?.first?.estimatedGain, 6)
    }

    /// A gap with no gain at all is not a decode failure.
    func testAMissingGainIsNotAFailure() throws {
        let json = #"{"reviewId":"r","fit":{"topGaps":[{"title":"t","category":"metrics"}]}}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(decoded.fit?.topGaps?.first?.title, "t")
        XCTAssertNil(decoded.fit?.topGaps?.first?.estimatedGain)
    }
}
