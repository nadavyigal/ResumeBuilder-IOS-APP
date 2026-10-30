import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S4: the sample CV is a labelled example that needs no network,
// and every new pricing v2 string (S2 to S4) has Hebrew.

@MainActor
final class PricingV2CopyTests: XCTestCase {
    func testTheSampleIsALabelledExampleWithAScoreInRange() {
        XCTAssertTrue((0...100).contains(SampleCV.score))
        XCTAssertEqual(SampleCV.cvLines.count, 3)
        XCTAssertFalse(SampleCV.matches.isEmpty)
        XCTAssertFalse(SampleCV.gaps.isEmpty)
        XCTAssertEqual(SampleCVCopy.note, "A made-up example, so you can see what you get. Your own Match Score is an estimate.")
    }

    /// The sample sheet takes no AppState, so it has no way to mark the paywall's
    /// "seen own score" milestone or send a real-score event.
    func testTheSampleSheetHasNoAppState() {
        let children = Mirror(reflecting: SampleCVSheet(onTryYours: {})).children
        XCTAssertFalse(children.contains { "\(type(of: $0.value))".contains("AppState") })
    }

    func testTheLinkedInStepsAreThreeShortSteps() {
        XCTAssertEqual(LinkedInHintCopy.steps.count, 3)
    }

    func testNewPricingStringsResolveInHebrew() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: path))
        let keys = [
            // S2
            "This subscription belongs to another Resumely account. Sign in with that account.",
            // S3
            "Download more tailored CVs",
            "A free chatbot gives you text. Resumely gives you a ready PDF, right-to-left in Hebrew, in a clean template, with a before-and-after Match Score estimate.",
            "Match Scores stay free and unlimited.",
            "Best value",
            "Pro, unlimited PDF downloads (fair use)",
            "Renews monthly until cancelled.",
            "Your Pro plan reached its fair-use limit for this billing period. A pack lets you keep downloading until it resets.",
            "The Match Score is an estimate of how well your CV fits the job, not a hiring prediction.",
            "Continue",
            "Restore Purchases",
            "14 tailored CVs",
            "5 tailored CVs",
            "%@ / month",
            "Nothing to restore for this Apple ID. Your PDF downloads stay on your Resumely account.",
            "We couldn't restore right now. Check your connection and try again.",
            "Your Pro plan is already active on this account.",
            "Check your Match Score on this screen first, then tap Export again.",
            "Your preview is still loading. Look it over, then tap Export again.",
            "Plan",
            "1 PDF download left",
            "%d PDF downloads left",
            "Pro until %@",
            "Pro, renews %@",
            "%1$d of %2$d PDF downloads used this period (fair use)",
            "Manage subscription",
            "Your Pro plan is restored.",
            "Your purchase is restored.",
            // S4
            "Check any job, free, as often as you like.",
            "Your Match Score is an estimate.",
            "Try a sample CV",
            "EXAMPLE",
            "Sample Match Score",
            "A made-up example, so you can see what you get. Your own Match Score is an estimate.",
            "The CV",
            "The job",
            "What already matches",
            "What's missing for this job",
            "Now try with your CV",
            "Dana Cohen · Marketing Coordinator · 3 years",
            "Ran monthly email campaigns for 12,000 subscribers",
            "Grew Instagram followers from 2,000 to 9,000 in a year",
            "Wrote product pages and blog posts with the sales team",
            "Digital Marketing Manager · Tel Aviv",
            "Email campaigns",
            "Social media growth",
            "Content writing",
            "Paid ads budget (Google, Meta)",
            "Leading a team",
            "Reports from analytics tools",
            "No CV file? Save your LinkedIn profile as PDF.",
            "How?",
            "Save your LinkedIn profile as a PDF",
            "Open linkedin.com in Safari (not the LinkedIn app) and go to your profile.",
            "Tap More, then Save to PDF.",
            "Save the file to Files, then come back and tap Choose a file.",
            "Got it",
        ]
        let fallbacks = keys.filter {
            hebrew.localizedString(forKey: $0, value: nil, table: nil) == $0
        }
        XCTAssertTrue(fallbacks.isEmpty, "\(fallbacks.count) pricing v2 keys fall back to English: \(fallbacks)")
    }
}
