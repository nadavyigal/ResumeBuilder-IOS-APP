import XCTest
@testable import ResumeBuilder_IOS_APP

/// The preview and the export share one direction rule, so a Hebrew résumé
/// exported before the preview loads is still right-to-left.
@MainActor
final class StyledResumeHTMLTests: XCTestCase {
    private let html = "<html><head></head><body><p>content</p></body></html>"

    func testHebrewSectionsMakeTheDocumentRTL() async {
        let sections = [OptimizedResumeSection(id: "summary", type: .summary, body: "מפתח iOS עם ניסיון בבניית אפליקציות", status: "optimized")]
        let out = StyledResumeHTML.applyingDirection(to: html, sections: sections, contact: nil)
        XCTAssertTrue(out.contains("<html dir=\"rtl\""))
    }

    func testEnglishSectionsLeaveTheDocumentUnchanged() async {
        let sections = [OptimizedResumeSection(id: "summary", type: .summary, body: "Builds reliable iOS apps.", status: "optimized")]
        XCTAssertEqual(StyledResumeHTML.applyingDirection(to: html, sections: sections, contact: nil), html)
    }

    func testMixedHebrewWithEnglishTechTermsStaysRTL() async {
        let sections = [OptimizedResumeSection(id: "summary", type: .summary, body: "פיתחתי בReact ו-Swift מערכת תשלומים", status: "optimized")]
        let out = StyledResumeHTML.applyingDirection(to: html, sections: sections, contact: nil)
        XCTAssertTrue(out.contains("<html dir=\"rtl\""))
    }

    func testWithoutSectionsTheRenderedHebrewTextDecides() async {
        let hebrewHTML = "<html><head></head><body><p>מהנדסת תוכנה בכירה</p></body></html>"
        let out = StyledResumeHTML.applyingDirection(to: hebrewHTML, sections: [], contact: nil)
        XCTAssertTrue(out.contains("<html dir=\"rtl\""))
    }

    func testLatinTagNamesDoNotOutweighShortHebrewText() async {
        let hebrewHTML = #"<html lang="he"><head><meta charset="utf-8"></head><body><div class="section-container"><p>שלום</p></div></body></html>"#
        let out = StyledResumeHTML.applyingDirection(to: hebrewHTML, sections: [], contact: nil)
        XCTAssertTrue(out.contains("<html dir=\"rtl\""))
    }

    func testRequestDefaultsToTheATSCleanTemplate() async {
        let request = StyledResumeHTML.request(optimizationId: "opt-1", templateId: nil, customization: nil)
        XCTAssertEqual(request.templateId, StyledResumeHTML.defaultTemplateId)
        XCTAssertEqual(request.optimizationId, "opt-1")
    }
}
