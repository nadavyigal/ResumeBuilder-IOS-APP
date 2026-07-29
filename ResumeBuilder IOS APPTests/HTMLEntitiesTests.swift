import XCTest
@testable import ResumeBuilder_IOS_APP

/// Job titles and company names are extracted from job descriptions that users
/// paste from web pages, so they arrive HTML-escaped. Nothing decoded them, and
/// a founder run on 2026-07-29 rendered `Sales &amp; Business Development
/// Manager` verbatim on the optimized preview and inside the diagnosis copy.
final class HTMLEntitiesTests: XCTestCase {

    func testDecodesTheAmpersandThatShippedOnDevice() {
        XCTAssertEqual(
            "Sales &amp; Business Development Manager".decodingHTMLEntities(),
            "Sales & Business Development Manager"
        )
    }

    func testDecodesCommonNamedEntities() {
        XCTAssertEqual("&lt;Head&gt;".decodingHTMLEntities(), "<Head>")
        XCTAssertEqual("&quot;Lead&quot;".decodingHTMLEntities(), "\"Lead\"")
        XCTAssertEqual("O&apos;Brien".decodingHTMLEntities(), "O'Brien")
        XCTAssertEqual("R&amp;D &ndash; EMEA".decodingHTMLEntities(), "R&D – EMEA")
    }

    func testDecodesNumericEntitiesDecimalAndHex() {
        XCTAssertEqual("AT&#38;T".decodingHTMLEntities(), "AT&T")
        XCTAssertEqual("AT&#x26;T".decodingHTMLEntities(), "AT&T")
        XCTAssertEqual("caf&#233;".decodingHTMLEntities(), "café")
    }

    /// `&amp;` is unescaped last, so a double-escaped entity decodes exactly one
    /// level rather than turning into markup.
    func testDoesNotDoubleDecode() {
        XCTAssertEqual("&amp;lt;script&amp;gt;".decodingHTMLEntities(), "&lt;script&gt;")
    }

    func testLeavesPlainTextAndUnknownEntitiesAlone() {
        XCTAssertEqual("Product Manager".decodingHTMLEntities(), "Product Manager")
        XCTAssertEqual("Tom & Jerry".decodingHTMLEntities(), "Tom & Jerry")
        XCTAssertEqual("100&percnt;".decodingHTMLEntities(), "100&percnt;")
        XCTAssertEqual("&#zzz;".decodingHTMLEntities(), "&#zzz;")
        XCTAssertEqual("".decodingHTMLEntities(), "")
    }

    // MARK: - Duplicate blocker copy

    /// The old guard was exact equality, so a detail line differing only in
    /// case, trailing whitespace or punctuation rendered as a duplicate
    /// directly under its own title.
    func testTreatsRestatedCopyAsEquivalent() {
        let title = "Move recent, relevant projects closer to the top of your experience"
        XCTAssertTrue(title.isEquivalentCopy(to: title))
        XCTAssertTrue(title.isEquivalentCopy(to: title + " "))
        XCTAssertTrue(title.isEquivalentCopy(to: title + "."))
        XCTAssertTrue(title.isEquivalentCopy(to: title.uppercased()))
        XCTAssertTrue(title.isEquivalentCopy(to: "  Move recent,   relevant projects closer to the top of your experience"))
    }

    func testKeepsGenuinelyDifferentDetail() {
        let title = "Add recent certifications"
        XCTAssertFalse(title.isEquivalentCopy(to: "Add recent certifications to demonstrate current expertise"))
        XCTAssertFalse(title.isEquivalentCopy(to: "Move recent projects up"))
        XCTAssertFalse(title.isEquivalentCopy(to: ""))
    }
}
