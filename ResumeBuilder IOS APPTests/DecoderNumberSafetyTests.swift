import XCTest
@testable import ResumeBuilder_IOS_APP

/// The trap PR #178 closed in `OptimizeFitGap`, closed everywhere else.
///
/// `Int(_:)` on a `Double` TRAPS — it kills the process, it does not throw —
/// when the value is outside `Int`'s range or is NaN. Every decoder below reads
/// numbers straight off the network, so before this change a malformed number
/// from the backend was a crash rather than a missing field.
///
/// `1e308` is the probe throughout: `Double` holds it, `Int` cannot, so it is
/// the smallest honest stand-in for "the backend sent a number we cannot use".
///
/// The second half of these tests pins something the trap hid. The
/// `KeyedDecodingContainer` helpers (`decodeInt`, `decodePercent`,
/// `decodeString`) used a bare `try`, and `decodeIfPresent` THROWS rather than
/// returning nil when a key is present but holds the wrong shape. So the first
/// branch aborted the whole decode and every fallback branch beneath it was
/// unreachable — including the `Int(_:)` line itself. Those helpers now use
/// `try?` and actually fall through.
@MainActor
final class DecoderNumberSafetyTests: XCTestCase {

    // MARK: - The site named in the report: ATSAuthSuggestion.estimated_gain

    func testAnAbsurdEstimatedGainYieldsNoValueRatherThanACrash() throws {
        let json = #"{"id":"s1","text":"Add metrics","estimated_gain":1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSAuthSuggestion.self, from: json)
        XCTAssertEqual(decoded.text, "Add metrics", "the suggestion survives")
        XCTAssertNil(decoded.estimatedGain, "an unrepresentable gain is a missing field, not a crash")
    }

    func testANegativelyAbsurdEstimatedGainAlsoYieldsNoValue() throws {
        let json = #"{"id":"s1","estimated_gain":-1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSAuthSuggestion.self, from: json)
        XCTAssertNil(decoded.estimatedGain)
    }

    /// The fractional gain from WP-59 still rounds. The fix must not cost the
    /// leniency PR #178 added.
    func testAFractionalEstimatedGainStillRounds() throws {
        let json = #"{"id":"s1","estimated_gain":2.5}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(ATSAuthSuggestion.self, from: json).estimatedGain, 3)
    }

    func testAWholeEstimatedGainStillDecodes() throws {
        let json = #"{"id":"s1","estimated_gain":6}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(ATSAuthSuggestion.self, from: json).estimatedGain, 6)
    }

    // MARK: - The helper named in the report: decodeInt(for:)

    /// `ATSOptimizationBlocker.estimatedGain` goes through `decodeInt(for:)`.
    func testAnAbsurdBlockerGainYieldsNoValueRatherThanACrash() throws {
        let json = #"{"id":"b1","title":"Add metrics","estimated_gain":1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSOptimizationBlocker.self, from: json)
        XCTAssertEqual(decoded.title, "Add metrics", "the blocker survives")
        XCTAssertNil(decoded.estimatedGain)
    }

    /// The bug the trap was hiding. `decodeInt` exists to accept a fractional
    /// number, but its bare `try` on the `Int` branch threw first and took the
    /// whole `ATSOptimizationBlocker` down with it — the same production break
    /// as the fractional `estimated_gain` in `OptimizeFitGap`.
    func testAFractionalBlockerGainDecodesInsteadOfKillingTheBlocker() throws {
        let json = #"{"id":"b1","title":"Add metrics","estimated_gain":2.5}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSOptimizationBlocker.self, from: json)
        XCTAssertEqual(decoded.title, "Add metrics")
        XCTAssertEqual(decoded.estimatedGain, 3, "2.5 rounds to 3 rather than failing the decode")
    }

    /// `ChatPendingChange.suggestionNumber` is non-optional with a `?? 0`
    /// default, so an unusable number degrades to 0 instead of trapping.
    func testAnAbsurdSuggestionNumberFallsBackToZero() throws {
        let json = #"{"suggestion_id":"c1","suggestion_number":1e308,"suggestion_text":"t"}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatPendingChange.self, from: json)
        XCTAssertEqual(decoded.suggestionId, "c1", "the pending change survives")
        XCTAssertEqual(decoded.suggestionNumber, 0)
    }

    // MARK: - decodePercent / normalizePercent

    /// `normalizePercent` clamped AFTER converting to `Int`, so the clamp never
    /// ran on the only input that needed it. It now clamps in `Double` space.
    func testAnAbsurdFitScoreClampsRatherThanCrashing() throws {
        let json = #"{"verdict":"strong","score":1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(FitVerdict.self, from: json)
        XCTAssertEqual(decoded.score, 100, "clamped to the top of the range, not a trap")
    }

    func testANegativelyAbsurdFitScoreClampsToZero() throws {
        let json = #"{"verdict":"weak","score":-1e308}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(FitVerdict.self, from: json).score, 0)
    }

    /// The fractional score `decodePercent` was written to accept, and which
    /// the bare `try` made unreachable.
    func testAFractionalFitScoreIsScaledInsteadOfFailing() throws {
        let json = #"{"verdict":"strong","score":0.82}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(FitVerdict.self, from: json).score, 82,
                       "0.82 scales to 82 rather than aborting the decode")
    }

    func testAWholeFitScoreStillDecodes() throws {
        let json = #"{"verdict":"strong","score":74}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(FitVerdict.self, from: json).score, 74)
    }

    // MARK: - The remaining decoders that read numbers off the wire

    func testAnAbsurdSubscoreYieldsNoValueRatherThanACrash() throws {
        let json = #"{"keyword_exact":1e308,"metrics_presence":12}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSSubScores.self, from: json)
        XCTAssertNil(decoded.keyword_exact, "the unusable subscore is dropped")
        XCTAssertEqual(decoded.metrics_presence, 12, "its neighbours are untouched")
    }

    func testAnAbsurdApplicationATSScoreYieldsNoValueRatherThanACrash() throws {
        let json = #"{"id":"app_1","job_title":"iOS Engineer","ats_score":1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ApplicationItem.self, from: json)
        XCTAssertEqual(decoded.id, "app_1", "the application survives")
        XCTAssertNil(decoded.atsScore)
    }

    func testAnAbsurdSelectionIndexYieldsNoValueRatherThanACrash() throws {
        let json = #"{"success":true,"selection_index":1e308}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: json)
        XCTAssertEqual(decoded.success, true, "the apply response survives")
        XCTAssertNil(decoded.selectionIndex)
    }

    /// The same reachability bug as the helpers: `selection_index` used a bare
    /// `try` on its Int branch, so a fractional value took the whole apply
    /// response with it instead of falling through to the Double branch.
    func testAFractionalSelectionIndexDecodesInsteadOfKillingTheResponse() throws {
        let json = #"{"success":true,"selection_index":2.0}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ExpertWorkflowApplyResponseDTO.self, from: json)
        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.selectionIndex, 2)
    }

    /// `ATSAuthScoreResult` requires both scores, so an unusable one is a
    /// thrown `DecodingError` the caller can catch — never a trap.
    func testAnAbsurdRequiredATSScoreThrowsRatherThanCrashing() {
        let json = #"{"ats_score_original":1e308,"ats_score_optimized":71}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ATSAuthScoreResult.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError, "a catchable error, not a crashed process")
        }
    }

    func testAnAbsurdRescanScoreThrowsRatherThanCrashing() {
        let json = #"{"success":true,"scores":{"original":1e308,"optimized":71}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ATSRescanResponse.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError, "a catchable error, not a crashed process")
        }
    }

    /// A rescan carrying the fractional scores it was built for still decodes.
    func testAFractionalRescanScoreStillScales() throws {
        let json = #"{"success":true,"scores":{"original":0.42,"optimized":0.71}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ATSRescanResponse.self, from: json)
        XCTAssertEqual(decoded.originalScore, 42)
        XCTAssertEqual(decoded.optimizedScore, 71)
    }
}
