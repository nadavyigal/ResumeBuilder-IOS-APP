import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// Guards the ATS-claim copy decisions (DECISIONS.md 2026-06-20): user-facing
/// copy uses the branded Resumely Match Score / Match language, keeps ATS only
/// in process-descriptive form (ATS-friendly), and never presents an "ATS score"
/// or "Free ATS Check" as the product's own metric.
@MainActor
final class CopyClaimsTests: XCTestCase {

    /// Phrases that must not appear in the surveyed user-facing copy.
    /// "ATS-friendly" stays allowed, so fragments are chosen to not match it.
    private let bannedFragments = [
        "ATS check",
        "ATS Check",
        "ATS score",
        "ATS Score",
        "Free ATS",
        "Improve ATS",
        "Improving ATS",
        "ATS insights",
        "ATS-safe",
        "pass ATS",
        "ATS Deep Report",
        "the way an ATS does"
    ]

    private func extractKey(_ key: LocalizedStringKey) -> String {
        for child in Mirror(reflecting: key).children where child.label == "key" {
            if let value = child.value as? String { return value }
        }
        XCTFail("Could not extract key from LocalizedStringKey")
        return ""
    }

    private func assertClean(_ text: String, context: String) {
        for fragment in bannedFragments {
            XCTAssertFalse(
                text.contains(fragment),
                "\(context) contains banned fragment \"\(fragment)\": \(text)"
            )
        }
    }

    // MARK: - Home activation states

    func testActivationHeadlinesUseMatchLanguage() async {
        let states: [HomeActivationState] = [
            .noResume, .resumeNoJob, .readyForFreeATS, .readyToOptimize,
            .atsComplete, .optimizing, .optimizedReady, .exportComplete
        ]
        for state in states {
            assertClean(extractKey(state.headline), context: "headline for \(state)")
            assertClean(extractKey(state.subheadline), context: "subheadline for \(state)")
        }
        XCTAssertEqual(extractKey(HomeActivationState.readyForFreeATS.headline),
                       "Ready for a free Match check")
    }

    // MARK: - Expert workflow copy

    func testExpertWorkflowCopyUsesMatchLanguage() async {
        for workflow in ExpertWorkflowType.allCases {
            assertClean(workflow.displayTitle, context: "displayTitle for \(workflow)")
            assertClean(workflow.cardDescription, context: "cardDescription for \(workflow)")
            assertClean(workflow.purposeText, context: "purposeText for \(workflow)")
        }
        XCTAssertEqual(ExpertWorkflowType.atsOptimizationReport.displayTitle,
                       "Match Deep Report")
        XCTAssertTrue(ExpertWorkflowType.fullResumeRewrite.cardDescription.contains("ATS-friendly"))
    }

    // MARK: - Share copy (Story 2)

    func testShareCopyUsesResumelyBrandingAndRealURLs() async {
        let scored = ResumePreviewViewModel(optimizationId: nil, atsScorePercent: 72)
        let line = scored.shareScoreLine ?? ""
        assertClean(line, context: "shareScoreLine")
        XCTAssertFalse(line.contains("on ATS"), "share line still claims an ATS score: \(line)")
        XCTAssertFalse(line.contains("ResumeBuilder AI"), "share line uses stale branding: \(line)")
        XCTAssertTrue(line.contains("Resumely Match Score"), "share line should name the branded score: \(line)")

        let fallback = ResumePreviewViewModel(optimizationId: nil, atsScorePercent: nil).shareScoreMessage
        XCTAssertFalse(fallback.contains("ResumeBuilder AI"), "share fallback uses stale branding: \(fallback)")
        XCTAssertTrue(fallback.contains("Resumely"), "share fallback should carry the brand: \(fallback)")

        XCTAssertFalse(ResumePreviewViewModel.shareAppURL.contains("vercel.app"),
                       "share URL still points at the internal deploy domain")
        XCTAssertFalse(LinkedInShareComposer.appStoreURL.contains("id000000000"),
                       "App Store URL still carries the placeholder id")
    }

    // MARK: - Marketing screenshot slots (Story 2)

    func testMarketingSlotsUseMatchLanguage() async {
        let extraBanned = ["ATS checker", "ATS resume score", "ATS safe", "any job"]
        for slot in MarketingScreenshotSlot.allCases {
            for text in [slot.headline, slot.subline, slot.caption] {
                assertClean(text, context: "marketing slot \(slot)")
                for fragment in extraBanned {
                    XCTAssertFalse(text.contains(fragment),
                                   "marketing slot \(slot) contains banned fragment \"\(fragment)\": \(text)")
                }
            }
        }
        XCTAssertEqual(MarketingScreenshotSlot.tailor.headline, "Your resume, tailored for this job")
    }

    /// G1b (market play 2026-10-14): App Store screenshots carry no "ATS" at all,
    /// not even the "ATS-friendly" form the in-app copy may keep.
    func testMarketingSlotsNeverSayATS() async {
        for slot in MarketingScreenshotSlot.allCases {
            for text in [slot.headline, slot.subline, slot.caption] {
                XCTAssertNil(text.range(of: #"\bATS\b"#, options: .regularExpression),
                             "marketing slot \(slot) mentions ATS: \(text)")
                XCTAssertFalse(text.contains("—"), "marketing slot \(slot) uses an em dash: \(text)")
            }
        }
    }

    // MARK: - Every shipped string (Release 1, story 8)

    /// Claims no shipped string may make, in English or Hebrew. "ATS-friendly"
    /// (process wording) and "not affiliated with any ATS vendor" (disclaimer) stay.
    private let bannedCatalogFragments = [
        "ATS match", "Best ATS", "ATS-Safe", "ATS signals", "ATS parsing",
        "ציון ATS", "התאמת ATS", "עמיד ב-ATS", "אותות ATS", "פענוח ATS", "ATS מיטבי"
    ]

    func testNoShippedStringClaimsAnATSScoreInEitherLanguage() throws {
        let lproj = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let tablePath = try XCTUnwrap(Bundle(path: lproj)?.path(forResource: "Localizable", ofType: "strings"))
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: tablePath) as? [String: String])
        XCTAssertGreaterThan(table.count, 100, "the Hebrew table did not load")
        for (english, hebrew) in table {
            assertClean(english, context: "catalog key")
            assertClean(hebrew, context: "Hebrew for \"\(english)\"")
            for fragment in bannedCatalogFragments {
                XCTAssertFalse(english.contains(fragment), "catalog key claims \"\(fragment)\": \(english)")
                XCTAssertFalse(hebrew.contains(fragment), "Hebrew claims \"\(fragment)\": \(hebrew)")
            }
        }
    }

    func testTheFitCheckDisclaimerNamesTheResumelyMatchScore() throws {
        let key = "Resumely Match Score: an estimate of fit for this job, not an employer's score. No optimization credit used."
        let lproj = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: lproj)).localizedString(forKey: key, value: nil, table: nil)
        XCTAssertNotEqual(hebrew, key, "Hebrew falls back to English")
        XCTAssertTrue(hebrew.contains("ציון ההתאמה של Resumely"), hebrew)
        XCTAssertFalse(key.contains("—"))
        XCTAssertFalse(hebrew.contains("—"))
    }

    func testTheTraditionalTemplateLabelMakesNoATSClaim() {
        for slug in ["traditional", "ats_safe", "ats-safe"] {
            let label = OptimizationDesignSheet.categoryLabel(for: slug)
            XCTAssertEqual(label, "Traditional · Simple layout")
            XCTAssertNil(label.range(of: #"\bATS\b"#, options: .regularExpression), label)
        }
    }
}

/// Guards the auth entry points (Story 3): "Create free account" must open the
/// sheet in sign-up mode, "Sign in" in sign-in mode, and the sheet must link
/// the live Privacy Policy and Terms pages.
@MainActor
final class AuthEntryTests: XCTestCase {

    func testOnboardingModeFollowsEntryPoint() async {
        let appState = AppState()
        XCTAssertTrue(OnboardingViewModel(appState: appState, startInSignUp: true).isSignUp,
                      "Create account entry should start in sign-up mode")
        XCTAssertFalse(OnboardingViewModel(appState: appState, startInSignUp: false).isSignUp,
                       "Sign in entry should start in sign-in mode")
        XCTAssertFalse(OnboardingViewModel(appState: appState).isSignUp,
                       "Default entry stays sign-in for existing flows")
    }

    func testAuthSheetLegalStringsHaveHebrew() async throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: path))
        for key in ["Terms of Use", "Privacy Policy"] {
            XCTAssertNotEqual(hebrew.localizedString(forKey: key, value: nil, table: nil), key,
                              "\(key) falls back to English in Hebrew")
        }
    }

    func testLegalLinksPointAtTheProductDomain() async {
        let apiHost = BackendConfig.apiBaseURL.host()
        let privacyEN = LegalLinks.privacyURL(language: .english)
        let termsEN = LegalLinks.termsURL(language: .english)
        XCTAssertEqual(privacyEN.host(), apiHost)
        XCTAssertEqual(termsEN.host(), apiHost)
        XCTAssertTrue(privacyEN.path().hasSuffix("/privacy"))
        XCTAssertTrue(termsEN.path().hasSuffix("/terms"))
        XCTAssertTrue(LegalLinks.privacyURL(language: .hebrew).path().hasPrefix("/he/"),
                      "Hebrew UI should open the Hebrew legal pages")
    }
}

/// Guards Hebrew parity for the post-FTUX strings the 2026-07-20 audit found
/// English-only (Story 5). Every key must resolve to a real Hebrew value in
/// the compiled he.lproj, not fall back to the English key.
@MainActor
final class HebrewParityTests: XCTestCase {

    func testPostFTUXStringsResolveInHebrew() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: path))
        let keys = [
            "%lld of %lld available changes selected",
            "Applied changes are ready to preview",
            "Blocked",
            "Check your connection, then try again.",
            "Checking your saved optimizations",
            "Checking your saved optimizations…",
            "Confirm & include",
            "Continue from the diagnosis you already ran",
            "Continue to optimize",
            "Couldn't restore your latest optimization. Check your connection and try again.",
            "Couldn’t save this resume. Your preview is still here — try again.",
            "Dismiss restored optimization message",
            "From the job post",
            "From your resume",
            "Keep this optimized resume in Saved Resumes so you can reuse it later.",
            "Latest optimization restored",
            "Optimized resumes you save from Preview will appear here.",
            "Save to My Resumes",
            "Saved in My Resumes",
            "Saved in My Resumes · Tap to preview",
            "Saving resume…",
            "Skip fit and optimize",
            "Suggestion hidden for safety",
            "The PDF has no selectable text. Please try exporting again.",
            "The projected score does not improve. No changes are selected by default—review each suggestion and include only changes you trust.",
            "This may add or change a number or metric. Confirm it is supported by your experience before including it.",
            "This may add, remove, or change a date. Confirm it is factually accurate before including it.",
            "This may change a company or employer name. Confirm it is factually accurate before including it.",
            "This may change a job title or seniority. Confirm it is factually accurate before including it.",
            "This may change a location. Confirm it is factually accurate before including it.",
            "This may change an education credential. Confirm it is factually accurate before including it.",
            "This may change contact information. Confirm it is factually accurate before including it.",
            "This suggestion contains unfinished template text, so it has been hidden and cannot be applied.",
            "Try Save Again",
            "Try restoring again",
            "We couldn't restore your latest optimization.",
            "Why this change",
            "Your Optimized, Design, Expert, and Account tabs are back in sync.",
            "Your optimized resume is not ready to save yet.",
            "Your résumé and diagnosis are untouched. You can adjust the target job and try again, or skip fit and optimize anyway.",
            "“%@”"
        ]
        let fallbacks = keys.filter {
            hebrew.localizedString(forKey: $0, value: nil, table: nil) == $0
        }
        XCTAssertTrue(fallbacks.isEmpty,
                      "\(fallbacks.count) post-FTUX keys fall back to English: \(fallbacks)")
    }
}
