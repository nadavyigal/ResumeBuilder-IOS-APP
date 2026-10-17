import XCTest
@testable import ResumeBuilder_IOS_APP

/// The Home "Add Job" step was stricter than the server (2026-10-16 read, build 1.5.1 (29),
/// external users): 4 of 5 people who picked a résumé stopped there. Two pasted under 100
/// words, one link failed the strict parser, and the one who converted fought the check for
/// 8 minutes. The optimize path (web `upload-resume`) needs only non-empty text; the web
/// treats 50 words as usable. The public free check still needs 100 words without a link.
@MainActor
final class JobInputPolicyTests: XCTestCase {

    private func words(_ count: Int) -> String {
        Array(repeating: "analyst", count: count).joined(separator: " ")
    }

    // MARK: Pasted text

    func testFiftyWordsAreEnoughToTailor() {
        for count in [50, 75, 99] {
            let evaluation = JobInputPolicy.evaluate(description: words(count), urlString: "")
            XCTAssertTrue(evaluation.isReady, "\(count) words should be accepted")
            XCTAssertNil(evaluation.blockingReason)
        }
    }

    func testUnderFiftyWordsIsStillTooShort() {
        let evaluation = JobInputPolicy.evaluate(description: words(49), urlString: "")
        XCTAssertFalse(evaluation.isReady)
        XCTAssertEqual(evaluation.blockingReason, .descriptionTooShort)
    }

    func testThePublicFreeCheckStillNeedsAHundredWords() {
        let short = JobInputPolicy.evaluate(description: words(99), urlString: "", destination: .publicCheck)
        XCTAssertEqual(short.blockingReason, .descriptionTooShort)
        XCTAssertTrue(JobInputPolicy.evaluate(description: words(100), urlString: "", destination: .publicCheck).isReady)
    }

    func testEmptyOrWhitespaceIsStillMissing() {
        XCTAssertEqual(JobInputPolicy.evaluate(description: "", urlString: "").blockingReason, .missing)
        XCTAssertEqual(JobInputPolicy.evaluate(description: "  \n\t ", urlString: "   ").blockingReason, .missing)
    }

    // MARK: Links

    func testALinkInsidePastedShareTextIsExtracted() {
        let shared = "Check out this job at Acme: https://www.linkedin.com/jobs/view/123456 via LinkedIn"
        let evaluation = JobInputPolicy.evaluate(description: "", urlString: shared)
        XCTAssertEqual(evaluation.normalizedURL, "https://www.linkedin.com/jobs/view/123456")
        XCTAssertTrue(evaluation.isReady)
    }

    func testTheFirstOfSeveralLinksIsUsed() {
        let shared = "Apply here https://jobs.example.com/a1 or see https://example.com/about"
        XCTAssertEqual(JobInputPolicy.evaluate(description: "", urlString: shared).normalizedURL, "https://jobs.example.com/a1")
    }

    func testABareDomainGetsHttps() {
        let evaluation = JobInputPolicy.evaluate(description: "", urlString: "linkedin.com/jobs/view/123")
        XCTAssertEqual(evaluation.normalizedURL, "https://linkedin.com/jobs/view/123")
    }

    func testAValidHttpsLinkIsUnchanged() {
        let link = "https://boards.greenhouse.io/acme/jobs/4012345?gh_src=abc"
        XCTAssertEqual(JobInputPolicy.evaluate(description: "", urlString: link).normalizedURL, link)
    }

    func testTextWithNoLinkIsStillAnInvalidLink() {
        let evaluation = JobInputPolicy.evaluate(description: "", urlString: "senior data analyst")
        XCTAssertNil(evaluation.normalizedURL)
        XCTAssertEqual(evaluation.blockingReason, .invalidURL)
    }

    // MARK: Which rule a first-session surface uses

    /// Home and Tailor send the text to the public check (100 words) when there is no
    /// session, and also when the fit check is on, because `prepareFitCheck` hands the
    /// same text to `FitCheckViewModel` (`.publicCheck`). Otherwise it goes to tailoring (50).
    func testFirstSessionDestinationFollowsWhereTheTextGoes() {
        XCTAssertEqual(JobInputPolicy.Destination.firstSession(canOptimize: true, isFitCheckEnabled: false), .optimize)
        XCTAssertEqual(JobInputPolicy.Destination.firstSession(canOptimize: true, isFitCheckEnabled: true), .publicCheck)
        XCTAssertEqual(JobInputPolicy.Destination.firstSession(canOptimize: false, isFitCheckEnabled: false), .publicCheck)
        XCTAssertEqual(JobInputPolicy.Destination.firstSession(canOptimize: false, isFitCheckEnabled: true), .publicCheck)
    }

    // MARK: Messages and analytics

    func testMessagesStateTheMinimumForTheDestination() {
        let tailor = JobInputPolicy.evaluate(description: words(10), urlString: "")
        XCTAssertEqual(tailor.validationMessage, "Paste at least 50 words from the job description (10 so far).")
        let check = JobInputPolicy.evaluate(description: words(10), urlString: "", destination: .publicCheck)
        XCTAssertEqual(check.validationMessage, "Paste at least 100 words from the job description (10 so far).")
    }

    func testWordCountBuckets() {
        XCTAssertEqual(JobInputPolicy.wordCountBucket(0), "0")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(1), "1-24")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(24), "1-24")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(25), "25-49")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(49), "25-49")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(50), "50-99")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(99), "50-99")
        XCTAssertEqual(JobInputPolicy.wordCountBucket(100), "100+")
    }

    func testValidationEventCarriesTheBucketButNeverTheText() {
        let properties = AnalyticsEvent.jobInputValidationShown(
            surface: "home",
            reason: "description_too_short",
            wordCountBucket: "25-49"
        ).properties
        XCTAssertEqual(properties, ["surface": "home", "reason": "description_too_short", "word_count_bucket": "25-49"])
    }
}
