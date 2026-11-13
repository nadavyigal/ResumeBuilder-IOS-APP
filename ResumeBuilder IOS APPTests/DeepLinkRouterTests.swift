import XCTest
@testable import ResumeBuilder_IOS_APP

/// `resumebuilder://share?url=...` is the only shape that becomes a shared job.
@MainActor
final class DeepLinkRouterTests: XCTestCase {
    private func parse(_ string: String) throws -> URL? {
        DeepLinkRouter.parseSharedJobURL(from: try XCTUnwrap(URL(string: string)))
    }

    func testTheShareLinkYieldsTheJobURL() throws {
        XCTAssertEqual(try parse("resumebuilder://share?url=https://jobs.example.com/1")?.absoluteString,
                       "https://jobs.example.com/1")
        XCTAssertEqual(try parse("ResumeBuilder://SHARE?url=http://jobs.example.com/2")?.absoluteString,
                       "http://jobs.example.com/2")
    }

    func testAnotherSchemeWithAShareHostIsRejected() throws {
        XCTAssertNil(try parse("https://share/?url=https://jobs.example.com/1"))
    }

    func testAnotherHostOnOurSchemeIsRejected() throws {
        XCTAssertNil(try parse("resumebuilder://signin?url=https://jobs.example.com/1"))
        XCTAssertNil(try parse("resumebuilder://open?url=https://jobs.example.com/1"))
    }

    func testOnlyWebJobLinksAreAccepted() throws {
        XCTAssertNil(try parse("resumebuilder://share?url=javascript:alert(1)"))
        XCTAssertNil(try parse("resumebuilder://share?url=file:///etc/hosts"))
        XCTAssertNil(try parse("resumebuilder://share"))
    }
}
