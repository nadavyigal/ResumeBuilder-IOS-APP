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
        XCTAssertEqual(JobLabel.normalized("Senior Position Manager"), "Senior Position Manager")
        XCTAssertEqual(JobLabel.normalized("Company Name Ltd"), "Company Name Ltd")
        XCTAssertNil(JobLabel.normalized("   "))
        XCTAssertNil(JobLabel.normalized(nil))
    }
}
