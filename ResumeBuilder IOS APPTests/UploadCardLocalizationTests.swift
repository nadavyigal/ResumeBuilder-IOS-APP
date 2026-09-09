import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// Regression guard for the Hebrew-in-English upload card (2026-09-09).
///
/// The Home/onboarding upload card rendered "PDF או DOCX · עד 5 MB" while the
/// HE/EN toggle was on EN. The subtitle was built with `NSLocalizedString`,
/// which resolves eagerly during SwiftUI body evaluation and returns a plain
/// `String`. `Bundle.setAppLanguage` swaps `Bundle.main`'s lookup bundle but
/// SwiftUI cannot observe that global, and the enclosing body was not
/// re-evaluated on the switch, so the Hebrew value computed under HE stayed on
/// screen. Every other string on that card is a `Text("literal")`
/// (`LocalizedStringKey`), which SwiftUI resolves at render time against
/// `\.environment(\.locale, …)` — those switched correctly.
///
/// The fix keeps the card's copy as `LocalizedStringKey` in `UploadCardCopy`.
/// These tests pin the keys to their English source text and prove both
/// language paths resolve to their own language.
@MainActor
final class UploadCardLocalizationTests: XCTestCase {

    /// `LocalizedStringKey` has no public accessor for its key, so mirror it —
    /// same approach as `CopyClaimsTests`.
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
            ("subtitle", UploadCardCopy.subtitle),
            ("uploadAccessibilityLabel", UploadCardCopy.uploadAccessibilityLabel),
            ("selectedAccessibilityLabel", UploadCardCopy.selectedAccessibilityLabel)
        ]
    }

    /// The keys are the English source strings, so an EN render never needs an
    /// `en.lproj` entry: the catalog's source language is `en` and the key *is*
    /// the English copy. This is what makes Hebrew impossible in EN mode.
    func testUploadCardCopyKeysAreEnglishSourceText() {
        XCTAssertEqual(extractKey(UploadCardCopy.subtitle), "PDF or DOCX · up to 5 MB")
        XCTAssertEqual(
            extractKey(UploadCardCopy.uploadAccessibilityLabel),
            "Upload your résumé. PDF or DOCX up to 5 megabytes."
        )
        XCTAssertEqual(
            extractKey(UploadCardCopy.selectedAccessibilityLabel),
            "Résumé selected. Choose a different file."
        )

        for entry in allCopy {
            XCTAssertFalse(
                containsHebrew(extractKey(entry.key)),
                "\(entry.name) key contains Hebrew characters: \(extractKey(entry.key))"
            )
        }
    }

    /// With the English override installed, every key must resolve to English —
    /// never to the Hebrew catalog value.
    func testEnglishOverrideNeverResolvesUploadCardCopyToHebrew() throws {
        let original = LocalizationManager.shared.language
        addTeardownBlock { @MainActor in
            Bundle.setAppLanguage(original.rawValue)
        }

        Bundle.setAppLanguage("en")
        for entry in allCopy {
            let key = extractKey(entry.key)
            let resolved = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertFalse(
                containsHebrew(resolved),
                "\(entry.name) resolved to Hebrew under the EN override: \(resolved)"
            )
            XCTAssertEqual(resolved, key, "\(entry.name) should fall through to its English key")
        }
    }

    /// Hebrew must still be translated — the fix must not silently drop HE copy.
    func testHebrewCatalogStillTranslatesUploadCardCopy() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrewBundle = try XCTUnwrap(Bundle(path: path))

        for entry in allCopy {
            let key = extractKey(entry.key)
            let translated = hebrewBundle.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(translated, key, "Hebrew falls back to English for \(entry.name)")
            XCTAssertTrue(
                containsHebrew(translated),
                "Hebrew translation for \(entry.name) has no Hebrew characters: \(translated)"
            )
        }
    }
}
