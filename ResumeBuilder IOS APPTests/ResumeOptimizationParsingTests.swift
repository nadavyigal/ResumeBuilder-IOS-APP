import XCTest
@testable import ResumeBuilder_IOS_APP

final class ResumeOptimizationParsingTests: XCTestCase {
    func testOptimizeResponseDecodesFlatPayload() throws {
        let json = """
        {
          "success": true,
          "optimization_id": "opt_123",
          "sections": [
            {
              "id": "summary",
              "type": "summary",
              "content": "Updated summary",
              "status": "optimized"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_123")
        XCTAssertEqual(response.sections?.count, 1)
        XCTAssertEqual(response.sections?.first?.body, "Updated summary")
    }

    func testOptimizeResponseDecodesNestedDataPayload() throws {
        let json = """
        {
          "data": {
            "success": true,
            "optimization_id": "opt_456",
            "sections": [
              {
                "id": "skills",
                "type": "skills",
                "content": "Swift, SwiftUI, Combine",
                "status": "improved",
                "ai_note": "Reordered by relevance"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_456")
        XCTAssertEqual(response.sections?.first?.type, .skills)
        XCTAssertEqual(response.sections?.first?.aiNote, "Reordered by relevance")
    }

    func testOptimizeResponseDecodesOptimizedResumeAlias() throws {
        let json = """
        {
          "success": true,
          "optimization_id": "opt_alias",
          "optimized_resume": [
            {
              "id": "experience",
              "type": "experience",
              "content": "Led migration reducing latency by 35%",
              "status": "optimized"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_alias")
        XCTAssertEqual(response.sections?.first?.type, .experience)
        XCTAssertEqual(response.sections?.first?.sectionStatus, .optimized)
    }
}
