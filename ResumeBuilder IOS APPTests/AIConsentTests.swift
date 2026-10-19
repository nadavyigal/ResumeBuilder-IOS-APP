import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// App Review 5.1.2(i): personal data may go to a third-party AI only after the
/// user is told and gives explicit permission. The résumé and job text leave the
/// phone when "Check my fit" runs (`HomeTabView.startCheck`), so the app asks
/// once there. These tests pin the stored answer, the copy, and the removal of
/// two labels that said the résumé is "never shared".
@MainActor
final class AIConsentTests: XCTestCase {

    /// A fresh, private defaults suite per test, removed when the test ends.
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "AIConsentTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return defaults
    }

    // MARK: Store

    func testNewInstallNeedsConsentBeforeSending() {
        let store = AIConsentStore(defaults: makeDefaults())
        XCTAssertFalse(store.hasConsented)
        XCTAssertTrue(store.needsConsentBeforeSending)
        XCTAssertNil(store.consentedAt)
    }

    func testRecordedConsentPersistsWithItsDate() {
        let defaults = makeDefaults()
        let date = Date(timeIntervalSince1970: 1_792_400_000)
        AIConsentStore(defaults: defaults).recordConsent(at: date)

        let reread = AIConsentStore(defaults: defaults)
        XCTAssertTrue(reread.hasConsented)
        XCTAssertFalse(reread.needsConsentBeforeSending)
        XCTAssertEqual(reread.consentedAt, date)
    }

    /// Versioned so a change in what is sent, or to whom, can ask again by
    /// bumping the key instead of migrating the stored answer.
    func testConsentKeyIsVersioned() {
        XCTAssertEqual(AIConsentStore.key, "ai_data_consent_v1")
    }

    // MARK: Copy

    private func extractKey(_ key: LocalizedStringKey) -> String {
        for child in Mirror(reflecting: key).children where child.label == "key" {
            if let value = child.value as? String { return value }
        }
        XCTFail("Could not extract key from LocalizedStringKey")
        return ""
    }

    private func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) }
    }

    private var allCopy: [(name: String, key: LocalizedStringKey)] {
        [
            ("title", AIConsentCopy.title),
            ("body", AIConsentCopy.body),
            ("agree", AIConsentCopy.agree),
            ("notNow", AIConsentCopy.notNow),
            ("privacyPolicy", AIConsentCopy.privacyPolicy)
        ]
    }

    func testCopyKeysAreTheEnglishSourceText() {
        XCTAssertEqual(extractKey(AIConsentCopy.title), "Before we read your résumé")
        XCTAssertEqual(
            extractKey(AIConsentCopy.body),
            "To check and improve your résumé, Resumely sends your résumé text and the job description to OpenAI, our AI provider. OpenAI processes them to write your results. If you check without an account, we keep the résumé and job text for up to 7 days."
        )
        XCTAssertEqual(extractKey(AIConsentCopy.agree), "Agree and continue")
        XCTAssertEqual(extractKey(AIConsentCopy.notNow), "Not now")
        XCTAssertEqual(extractKey(AIConsentCopy.privacyPolicy), "Privacy Policy")
    }

    /// The disclosure has to name the provider, in both languages.
    func testBodyNamesTheAIProvider() throws {
        XCTAssertTrue(extractKey(AIConsentCopy.body).contains("OpenAI"))

        let hebrew = try hebrewBundle()
        let translated = hebrew.localizedString(forKey: extractKey(AIConsentCopy.body), value: nil, table: nil)
        XCTAssertTrue(translated.contains("OpenAI"), "Hebrew body must name OpenAI: \(translated)")
    }

    func testHebrewCatalogTranslatesEveryConsentString() throws {
        let hebrew = try hebrewBundle()
        for entry in allCopy {
            let key = extractKey(entry.key)
            let translated = hebrew.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(translated, key, "Hebrew falls back to English for \(entry.name)")
            XCTAssertTrue(containsHebrew(translated), "No Hebrew in \(entry.name): \(translated)")
        }
    }

    func testCopyHasNoEmDashes() throws {
        let hebrew = try hebrewBundle()
        for entry in allCopy {
            let key = extractKey(entry.key)
            XCTAssertFalse(key.contains("\u{2014}"), "Em dash in English \(entry.name)")
            let translated = hebrew.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertFalse(translated.contains("\u{2014}"), "Em dash in Hebrew \(entry.name)")
        }
    }

    // MARK: Removed claims

    /// "Encrypted and never shared" and "encrypted end-to-end" were false next to
    /// a send to OpenAI. Their catalog entries must stay gone.
    func testCatalogCarriesNoNeverSharedClaim() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "he")
        )
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        let banned = ["never shared", "end-to-end", "לעולם לא משותפים", "מקצה לקצה"]
        for (key, value) in table {
            for fragment in banned {
                XCTAssertFalse(key.contains(fragment), "Catalog key still claims \"\(fragment)\": \(key)")
                XCTAssertFalse(value.contains(fragment), "Hebrew value still claims \"\(fragment)\": \(value)")
            }
        }
    }

    private func hebrewBundle() throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
