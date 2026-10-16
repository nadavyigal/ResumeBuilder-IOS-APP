import XCTest
@testable import ResumeBuilder_IOS_APP

/// The web API saves "Job Position" / "Company Name" when it cannot read a title
/// or company from the job (and the review flow falls back to "Position"). The
/// optimized preview rendered them verbatim: `Company Name Job Position`
/// (iOS capture, 2026-10-12). They mean "unknown" and must decode as nil.
@MainActor
final class JobLabelPlaceholderTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testOptimizationDetailDropsServerPlaceholders() throws {
        let detail = try decode(
            OptimizationDetailDTO.self,
            #"{"sections": [], "job_title": "Job Position", "company": "Company Name"}"#
        )
        XCTAssertNil(detail.jobTitle)
        XCTAssertNil(detail.company)
    }

    func testOptimizationDetailKeepsRealValues() throws {
        let detail = try decode(
            OptimizationDetailDTO.self,
            #"{"sections": [], "job_title": "Data Analyst", "company": "Kesher Commerce"}"#
        )
        XCTAssertEqual(detail.jobTitle, "Data Analyst")
        XCTAssertEqual(detail.company, "Kesher Commerce")
    }

    func testReviewJobDescriptionDropsServerPlaceholders() throws {
        let jd = try decode(
            OptimizationReviewJobDescriptionDTO.self,
            #"{"title": "Position", "company": "Company Name", "raw_text": "x"}"#
        )
        XCTAssertNil(jd.title)
        XCTAssertNil(jd.company)
        XCTAssertEqual(jd.rawText, "x")
    }

    func testHistoryAndApplicationRowsDropServerPlaceholders() throws {
        let history = try decode(
            OptimizationHistoryItem.self,
            #"{"id": "o1", "job_title": " job position ", "company_name": "Company Name"}"#
        )
        XCTAssertNil(history.jobTitle)
        XCTAssertNil(history.company)

        let application = try decode(
            ApplicationItem.self,
            #"{"id": "a1", "job_title": "Job Position", "company_name": "Company Name"}"#
        )
        XCTAssertNil(application.jobTitle)
        XCTAssertNil(application.companyName)
    }

    func testLabelThatOnlyContainsAPlaceholderWordIsKept() {
        XCTAssertEqual(JobLabel.title("Senior Position Manager"), "Senior Position Manager")
        XCTAssertEqual(JobLabel.company("Company Name Ltd"), "Company Name Ltd")
        XCTAssertNil(JobLabel.title("   "))
        XCTAssertNil(JobLabel.company(nil))
    }

    // A sentinel belongs to the field the server writes it into (PR #188 review,
    // 2026-10-13): "Position" and "Job Position" are title defaults, "Company Name"
    // is the company default. A company really named "Position" must survive.

    func testCompanyNamedPositionIsKeptEverywhere() throws {
        let detail = try decode(
            OptimizationDetailDTO.self,
            #"{"sections": [], "job_title": "Data Analyst", "company": "Position"}"#
        )
        XCTAssertEqual(detail.company, "Position")

        let jd = try decode(
            OptimizationReviewJobDescriptionDTO.self,
            #"{"title": "Data Analyst", "company": "Job Position"}"#
        )
        XCTAssertEqual(jd.company, "Job Position")

        let history = try decode(
            OptimizationHistoryItem.self,
            #"{"id": "o1", "job_title": "Data Analyst", "company_name": "Position"}"#
        )
        XCTAssertEqual(history.company, "Position")

        let application = try decode(
            ApplicationItem.self,
            #"{"id": "a1", "job_title": "Data Analyst", "company_name": "Position"}"#
        )
        XCTAssertEqual(application.companyName, "Position")
    }

    func testTitleCalledCompanyNameIsKept() throws {
        let detail = try decode(
            OptimizationDetailDTO.self,
            #"{"sections": [], "job_title": "Company Name", "company": "Kesher Commerce"}"#
        )
        XCTAssertEqual(detail.jobTitle, "Company Name")

        let application = try decode(
            ApplicationItem.self,
            #"{"id": "a1", "job_title": "Company Name", "company_name": "Kesher Commerce"}"#
        )
        XCTAssertEqual(application.jobTitle, "Company Name")
    }

    /// AGENTS.md: every new type is `Sendable` or `@MainActor` (Swift 6 strict
    /// concurrency). This does not compile if `JobLabel` loses its conformance.
    func testJobLabelIsSendable() {
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(JobLabel.self)
    }

    func testEachFieldDropsOnlyItsOwnSentinel() {
        XCTAssertNil(JobLabel.title("Position"))
        XCTAssertNil(JobLabel.title(" job position "))
        XCTAssertNil(JobLabel.company("Company Name"))
        XCTAssertEqual(JobLabel.company("Position"), "Position")
        XCTAssertEqual(JobLabel.company("Job Position"), "Job Position")
        XCTAssertEqual(JobLabel.title("Company Name"), "Company Name")
    }
}
