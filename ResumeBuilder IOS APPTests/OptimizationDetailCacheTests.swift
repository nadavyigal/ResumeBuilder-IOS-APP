import XCTest
@testable import ResumeBuilder_IOS_APP

final class OptimizationDetailCacheTests: XCTestCase {
    func testEvictsOldestEntryWhenOverLimit() throws {
        var cache = OptimizationDetailCache()
        let detail = try makeDetail()
        for index in 0..<12 {
            cache.store(detail, for: "opt-\(index)")
        }
        XCTAssertNil(cache.value(for: "opt-0"))
        XCTAssertNil(cache.value(for: "opt-1"))
        XCTAssertNotNil(cache.value(for: "opt-11"))
    }

    func testRemoveDeletesStoredDetail() throws {
        var cache = OptimizationDetailCache()
        let detail = try makeDetail()
        cache.store(detail, for: "opt-1")
        cache.remove("opt-1")
        XCTAssertNil(cache.value(for: "opt-1"))
    }

    private func makeDetail() throws -> OptimizationDetailDTO {
        let json = Data("{\"sections\":[]}".utf8)
        return try JSONDecoder().decode(OptimizationDetailDTO.self, from: json)
    }
}
